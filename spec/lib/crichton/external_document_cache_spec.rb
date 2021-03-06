require 'json'
require 'spec_helper'
require 'fileutils'
require 'crichton/external_document_cache'

module Crichton
  describe ExternalDocumentCache do
    def prepare_metadata_file
      new_metadata  = {
          link:    @link,
          status:  200,
          headers: @headers || {},
          time:    @time || (Time.now - 30) }
      @metafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.meta.json")
      File.open(@metafilename, 'wb') { |f| f.write(new_metadata.to_json) }
      new_metadata
    end

    describe '.new' do
      before do
          @pathname = 'test/path'
      end

      it 'accepts a cache path' do
        expect(Dir).to receive(:exists?).with(@pathname).and_return(true)
        ExternalDocumentCache.new(@pathname)
      end

      it 'uses the configured cache path if none is explicitly passed into the new call' do
        allow(Crichton.config).to receive(:external_documents_store_directory).and_return(@pathname)
        expect(Dir).to receive(:exists?).with(@pathname).and_return(true)
        ExternalDocumentCache.new(@pathname)
      end

      it 'creates the cache path if it does not exist' do
        allow(Dir).to receive(:exists?).and_return(false)
        expect(FileUtils).to receive(:mkdir_p).with(@pathname).and_return(true)
        ExternalDocumentCache.new(@pathname)
      end
    end

    describe '#get' do
      before do
        @pathname = File.join('spec', 'fixtures', 'external_documents_cache')
        FileUtils.mkdir_p(@pathname) unless Dir.exists?(@pathname)
        @link = 'http://some.url:1234/somepath'
        @datafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.cache")
        File.open(@datafilename, 'wb') { |f| f.write("Testfile #{@link}") }
      end

      context 'in the basic case' do
        before do
          @time =  Time.now + 1000
          prepare_metadata_file
        end

        it 'reads the data file and returns the data' do
          edc = ExternalDocumentCache.new(@pathname)
          expect(edc.get(@link)).to eq("Testfile #{@link}")
        end
      end

      context 'in case of outdated metadata' do
        before do
          @time =  Time.now - 100000
          prepare_metadata_file
        end

        it 'tries to verify the data and accepts a 304 response' do
          edc = ExternalDocumentCache.new(@pathname)
          stub = stub_request(:get, @link).to_return(status: 304, body: '', headers: {})
          edc.get(@link)
          expect(stub).to have_been_requested
        end

        it 'tries to verify the data and returns the data from the file in case of a 304' do
          @datafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.cache")
          File.open(@datafilename, 'wb') { |f| f.write("Testfile #{@link}") }
          edc = ExternalDocumentCache.new(@pathname)
          stub_request(:get, @link).to_return(status: 304, body: '', headers: {})
          expect(edc.get(@link)).to eq("Testfile #{@link}")
        end

        it 'tries to verify the data and returns the data from the file in case of a 404' do
          @datafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.cache")
          File.open(@datafilename, 'wb') { |f| f.write("Testfile #{@link}") }
          edc = ExternalDocumentCache.new(@pathname)
          stub_request(:get, @link).to_return(status: 404, body: '', headers: {})
          expect(edc.get(@link)).to eq("Testfile #{@link}")
        end

        it 'tries to verify the data and updates the metadata in the file' do
          edc = ExternalDocumentCache.new(@pathname)
          stub_request(:get, @link).to_return(status: 304, body: '', headers: {})
          edc.get(@link)
          json_data = JSON.parse(File.open(@metafilename, 'rb') { |f| f.read })
          # In the before, the time is set to a VERY early time - so if it's within 5 seconds then we're good
          expect((Time.parse(json_data['time']) - Time.now).abs).to be < 5
        end

        it 'handles a connection refused error by returning the cached data' do
          @datafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.cache")
          File.open(@datafilename, 'wb') { |f| f.write("Testfile #{@link}") }
          edc = ExternalDocumentCache.new(@pathname)
          stub_request(:get, @link).to_raise(Errno::ECONNREFUSED)
          expect(edc.get(@link)).to eq("Testfile #{@link}")
        end

        it 'handles a connection refused error by logging a warning' do
          @datafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.cache")
          File.open(@datafilename, 'wb') { |f| f.write("Testfile #{@link}") }
          expect(Crichton.logger).to receive(:warn).with("Log connection refused: #{@link}")
          edc = ExternalDocumentCache.new(@pathname)
          stub_request(:get, @link).to_raise(Errno::ECONNREFUSED)
          edc.get(@link)
        end

        it 'handles other errors by returning the cached data' do
          @datafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.cache")
          File.open(@datafilename, 'wb') { |f| f.write("Testfile #{@link}") }
          edc = ExternalDocumentCache.new(@pathname)
          stub_request(:get, @link).to_raise(Errno::EADDRINUSE)
          expect(edc.get(@link)).to eq("Testfile #{@link}")
        end

        it 'handles other errors by returning the cached data' do
          @datafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.cache")
          File.open(@datafilename, 'wb') { |f| f.write("Testfile #{@link}") }
          expect(Crichton.logger).to receive(:warn).
              with("Address already in use - Exception from WebMock while getting #{@link}")
          edc = ExternalDocumentCache.new(@pathname)
          stub_request(:get, @link).to_raise(Errno::EADDRINUSE)
          edc.get(@link)
        end
      end

      context 'metadata with cache control' do
        it 'accepts data that is new enough' do
          @headers = {'cache-control' => ['max-age=20']}
          @time =  Time.now - 2
          prepare_metadata_file
          stub = stub_request(:get, @link).to_return(status: 404)
          edc = ExternalDocumentCache.new(@pathname)
          expect(edc.get(@link)).to eq("Testfile #{@link}")
          expect(stub).to have_not_been_made
        end

        it 're-validated data that is too old' do
          @headers = {'cache-control' => ['max-age=20']}
          prepare_metadata_file
          stub = stub_request(:get, @link).to_return(status: 304)
          edc = ExternalDocumentCache.new(@pathname)
          edc.get(@link)
          expect(stub).to have_been_made
        end

        it 're-validated data that young enough but has the must-revalidate header set' do
          @headers = {'cache-control' => ['max-age=200, must-revalidate']}
          prepare_metadata_file
          edc = ExternalDocumentCache.new(@pathname)
          stub_request(:get, @link).to_return(status: 304, body: '', headers: {})
          expect(edc.get(@link)).to eq("Testfile #{@link}")
        end

        it 're-validated data that young enough but has the no-cache header set' do
          @headers = {'cache-control' => ['max-age=200, no-cache']}
          prepare_metadata_file
          edc = ExternalDocumentCache.new(@pathname)
          stub_request(:get, @link).to_return(status: 304, body: '', headers: {})
          expect(edc.get(@link)).to eq("Testfile #{@link}")
        end
      end

      context 'with custom metadata' do
        before do
          @time =  Time.now - 100000
        end

        it 'sends the ETAG along in the request' do
          @headers = {'etag' => ['1234']}
          prepare_metadata_file
          stub = stub_request(:get, @link).with(headers: {'If-None-Match' => '1234'}).
            to_return(status: 304, body: '', headers: {})
          edc = ExternalDocumentCache.new(@pathname)
          edc.get(@link)
          expect(stub).to have_been_requested
        end

        it 'sends the last modified along in the request' do
          @headers = {'last-modified' => ['1234']}
          new_metadata = prepare_metadata_file
          @metafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.meta.json")
          File.open(@metafilename, 'wb') { |f| f.write(new_metadata.to_json) }
          stub = stub_request(:get, @link).with(headers: {'If-Modified-Since'=>'1234'}).
            to_return(:status => 304, :body => '', headers: {})
          edc = ExternalDocumentCache.new(@pathname)
          edc.get(@link)
          expect(stub).to have_been_requested
        end

        context 'in case of a cache miss' do
          before do
            @pathname = File.join('spec', 'fixtures', 'external_documents_cache')
            FileUtils.mkdir_p(@pathname) unless Dir.exists?(@pathname)
            @metafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.meta.json")
            File.delete(@metafilename) if File.exist?(@metafilename)
            @datafilename = File.join(@pathname, "#{Digest::MD5.hexdigest(@link)}.cache")
          end

          it 'writes the received data to the cache' do
            File.delete(@datafilename) if File.exist?(@datafilename)
            edc = ExternalDocumentCache.new(@pathname)
            stub_request(:get, @link).to_return(status: 200, body: 'Data', headers: {'headers' => 'Headerdata'})
            edc.get(@link)
            json_data = JSON.parse(File.open(@metafilename, 'rb') { |f| f.read })
            expect(json_data).to include(
              {
                'link' => 'http://some.url:1234/somepath',
                'status' => '200',
                'headers' => {'headers' => ['Headerdata']}
              })
          end

          it ' but en existing data file, writes the new data' do
            File.open(@datafilename, 'wb') { |f| f.write('old junk')}
            edc = ExternalDocumentCache.new(@pathname)
            stub_request(:get, @link).to_return(status: 200, body: 'Data', headers: {'headers' => 'Headerdata'})
            edc.get(@link)
            json_data = JSON.parse(File.open(@metafilename, 'rb') { |f| f.read })
            expect(json_data).to include(
              {
                'link' => 'http://some.url:1234/somepath',
                'status' => '200',
                'headers' => {'headers' => ['Headerdata']}
              })
          end
        end
      end
    end
  end
end
