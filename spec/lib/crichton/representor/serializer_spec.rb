require 'spec_helper'
require 'crichton/representor/serializer'

module Crichton
  module Representor
    describe Serializer do
      before(:all) do
        @existing_serializers = Serializer.registered_serializers
      end
      
      after(:all) do
        # Necessary since other specs load serializers so that randomization does not cause erroneous failures
        # since registered_serializers is a class method.
        reset_serializers(@existing_serializers)
      end
      
      def create_media_type_serializer(serializer = nil)
        serializer ||= :MediaTypeSerializer
        Crichton::Representor.send(:remove_const, serializer) if Representor.const_defined?(serializer)
        reset_serializers
        
        eval("class #{serializer} < Crichton::Representor::Serializer; end")
      end

      def reset_serializers(value = {})
        Serializer.instance_variable_set('@registered_serializers', value)
      end

      let(:object) do
        Class.new { include Representor }.new
      end

      context 'when subclassed' do
        context 'with serializer subclasses with well-formed names' do
          it 'auto registers sublclassed serializers' do
            create_media_type_serializer
            Serializer.registered_serializers[:media_type].should == MediaTypeSerializer
          end
        end

        context 'with alternate media types defined for the serializer' do
          before do
            eval("class MediaTypeSerializer < Crichton::Representor::Serializer; alternate_media_types " <<
              ":alt_media_type, 'other_alt_media_type'; end")
          end
          
          it 'auto registers alternate media types as symbols' do
            Serializer.registered_serializers[:alt_media_type].should == MediaTypeSerializer
          end

          it 'auto registers alternate media types as strings' do
            Serializer.registered_serializers[:other_alt_media_type].should == MediaTypeSerializer
          end
        end

        context 'with serializer subclasses with mal-formed names' do
          it 'raises an error when the name does not end in Serializer' do
            @serializer = :MediaTypeSerializers
            expect { create_media_type_serializer(@serializer) }.to raise_error(Crichton::Representor::Error,
              /Subclasses .* must follow the naming convention OptionalModule::MediaTypeSerializer.*/)
          end
        end
      end

      describe '.build' do
        context 'with existing subclasses' do
          before do
            create_media_type_serializer
          end

          it 'builds serializer instances associated with a media type' do
            Serializer.build(:media_type, object).should be_instance_of(MediaTypeSerializer)
          end

          it 'raises an error if object is not a Crichton::Representor' do
            expect { Serializer.build(:media_type, mock('object')) }.to raise_error(ArgumentError,
              /^The object .* is not a Crichton::Representor.$/)
          end
        end

        it 'raises an error if the type does not have a registered serializer' do
          expect { Serializer.build(:some_media_type, object) }.to raise_error(Crichton::Representor::Error,
            /^No representor serializer is registered that corresponds to the type 'some_media_type'.$/)
        end
      end

      describe '.registered_serializers' do
        context 'without any registered serializers' do
          it 'returns an empty hash if no serializers are registered' do
            reset_serializers
            Serializer.registered_serializers.should == {}
          end
        end

        context 'with existing subclasses with well-formed names' do
          it 'returns a hash of registered serializer classes' do
            create_media_type_serializer
            Serializer.registered_serializers[:media_type].should == MediaTypeSerializer
          end
        end
      end
    end
  end
end
