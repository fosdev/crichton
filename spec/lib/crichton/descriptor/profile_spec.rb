require 'spec_helper'

module Crichton
  module Descriptor
    describe Profile do
      let(:descriptors) { drds_descriptor['descriptors'] }
      let(:resource_descriptor) { mock('resource_descriptor') }
      let(:descriptor) { Profile.new(resource_descriptor, @descriptor) }

      before do
        @descriptor = descriptors['drds']
      end

      describe '.new' do
        it 'returns a subclass of Base' do
          descriptor.should be_a(Base)
        end

        it_behaves_like 'a nested descriptor'
      end
  
      describe '#descriptors' do
        context 'with nested descriptors' do
          it 'returns a populated array' do
            descriptor.descriptors.should_not be_empty
          end
  
          it 'returns an array of descriptors' do
            descriptor.descriptors.all? { |descriptor| descriptor.is_a?(Base) }.should be_true
          end
        end
  
        context 'without nested descriptors' do
          it 'returns an empty array if there are no nested descriptors' do
            @descriptor = drds_descriptor.reject { |k, _| k == 'descriptors' }
            descriptor.descriptors.should be_empty
          end
        end
      end

      describe '#help_link' do
        it 'returns the help link in the descriptor' do
          descriptors['drds']['links'] = {'help' => 'help_link'}
          descriptor.help_link.href.should == 'http://docs.example.org/help_link'
        end
        
        it 'returns the resource descriptor help link if no help link in descriptor' do
          link = mock('help_link')
          resource_descriptor.stub(:help_link).and_return(link)
          descriptor.help_link.should == link
        end
      end

      describe '#links' do
        it 'returns the descriptor links' do
          descriptor.links['self'].should_not be_nil
        end
      end

      describe '#semantics' do
        context 'with nested semantic descriptors' do
          it 'returns a populated hash' do
            descriptor.semantics.should_not be_empty
          end
  
          it 'returns an hash of semantic descriptors' do
            descriptor.semantics.all? { |_, descriptor| descriptor.semantic? }.should be_true
          end
        end 
  
        context 'without nested semantic descriptors' do
          it 'returns an empty hash if there are no nested semantic descriptors' do
            @descriptor['descriptors'].reject! { |_, descriptor| descriptor['type'] == 'semantic' }
            descriptor.semantics.should be_empty
          end
        end
      end
  
      describe '#transitions' do
        context 'with nested transition descriptors' do
          it 'returns a populated hash' do
            descriptor.transitions.should_not be_empty
          end
  
          it 'returns a hash of transition descriptors' do
            descriptor.transitions.all? { |_, descriptor| descriptor.transition? }.should be_true
          end
        end
  
        context 'without nested transition descriptors' do
          it 'returns an empty hash if there are no nested transition descriptors' do
            @descriptor['descriptors'].reject! { |descriptor| descriptor['type'] != 'semantic' }
            descriptor.transitions.should be_empty
          end
        end
      end
    end
  end
end
