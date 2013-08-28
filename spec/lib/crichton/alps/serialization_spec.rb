require 'spec_helper'

module Crichton
  module ALPS 
    describe Serialization do
      class SimpleAlpsTestClass 
        include Serialization

        (ALPS_ATTRIBUTES | ALPS_ELEMENTS).each do |property|
          next if property == 'link'
          define_method(property) do
            descriptor_document[property]
          end
        end
        
        def links
          @links ||= (descriptor_document['links'] || {}).inject({}) do |h, (rel, href)|
            h.tap { |hash| hash[rel] = Crichton::Descriptor::Link.new(self, rel, href) }
          end
        end
        alias :link :links

        define_method('descriptors') do
          (descriptor_document['descriptors'] || {}).inject([]) do |a, (id, descriptor)|
            a << SimpleAlpsTestClass.new(descriptor, id)
          end
        end
        
        def initialize(descriptor_document, id)
          @descriptor_document = descriptor_document && descriptor_document.dup || {}
          @descriptor_document['id'] = id
        end
        
        attr_reader :descriptor_document
      end
    
      let(:descriptor) { SimpleAlpsTestClass.new(leviathans_descriptor, 'Leviathans') }
      
      describe '#alps_attributes' do
        it 'returns a hash of alps descriptor attributes' do
          descriptor.alps_attributes.should == {'id' => 'Leviathans'}
        end
      end

      describe '#alps_descriptors' do
        it 'returns an array of alps descriptor hashes' do
          descriptor.alps_descriptors.map { |descriptor| descriptor['id'] }.should == %w(leviathan)
        end
      end

      describe '#alps_elements' do
        it 'returns a hash of alps descriptor elements' do
          descriptor.alps_elements.should == {
              'doc' => {'value' => 'Describes Leviathans.'},
              'ext' => [
                {'href' => 'Leviathans#leviathan/alt', 'value' => 'Alternate.'}
              ],
              'link' => [
                  {'rel' => 'self', 'href' => 'http://alps.example.com/Leviathans'},
                  {'rel' => 'help', 'href' => 'http://docs.example.org/Things/Leviathans'}
              ]
          }
        end
      end

      it_behaves_like 'it serializes to ALPS'
    end
  end
end
