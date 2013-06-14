require 'spec_helper'
require 'crichton/representor'
require 'crichton/representor/factory'
require 'crichton/representor/serializers/xhtml'

module Crichton
  module Representor
    describe XHTMLSerializer do
      class ::DRD
        include Representor::State
        extend Representor::Factory

        represents :drd

        def self.apply_methods
          data_semantic_descriptors.each do |descriptor|
            name = descriptor.name
            define_method(name) { @attributes[name] }
          end
        end
        
        def self.all(options = nil)
          drds = {
            'total_count' => 2,
            'items' => 2.times.map { |i| new(i) }
          }
          build_state_representor(drds, :drds, {state: 'collection'})
        end

        def initialize(i)
          @attributes = {}
          @attributes = %w(name status kind leviathan_uuid built_at).inject({}) { |h, attr| h[attr] = "#{attr}_#{i}"; h }
          @attributes['uuid'] = i
        end
        
        # TODO: develop state specification options for embedded semantics
        def state
          :activated
        end
        
        def leviathan_url
          # Note: this is not advocating templating this, but rather just a method to demonstrate
          # the protocol implementation for URI source.
          "http://example.org/leviathan/#{leviathan_uuid}" if leviathan_uuid =~ /_1/
        end
      end

      before do
        # Can't apply methods without a stubbed configuration and registered descriptors
        stub_example_configuration
        register_descriptor(drds_descriptor)
        DRD.apply_methods
      end

      it 'self-registers as a serializer for the xhtml media-type' do
        Serializer.registered_serializers[:xhtml].should == XHTMLSerializer
      end

      it 'self-registers as a serializer for the html media-type' do
        Serializer.registered_serializers[:html].should == XHTMLSerializer
      end
      
      describe '#as_media_type' do
        context 'without styled interface for API surfing' do
          it 'returns the resource represented as xhtml' do
            serializer = XHTMLSerializer.new(DRD.all)
            serializer.as_media_type(conditions: 'can_do_anything').should be_equivalent_to(drds_microdata_html)
          end
        end

        context 'with styled interface for API surfing' do
          it 'returns the resource represented as xhtml' do
            options = {conditions: 'can_do_anything', semantics: :styled_microdata}
            serializer = XHTMLSerializer.new(DRD.all)
            serializer.as_media_type(options).should be_equivalent_to(drds_styled_microdata_html)
          end
        end
      end
    end
  end
end
