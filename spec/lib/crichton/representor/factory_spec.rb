require 'spec_helper'
require 'crichton/representor/factory'

module Crichton
  module Representor
    describe Factory do
      before do
        Factory.clear_factory_classes
        register_drds_descriptor
      end
      let(:simple_test_class) { Class.new }
      let(:target) do
        @target && @target.is_a?(Hash) ? @target : mock('target').tap { |target| target.stub(:name).and_return('1812') }
      end

      shared_examples_for 'a memoized factory class' do
        it 'memoizes the factory class' do
          class_object_id = representor.class.object_id
          representor.class.object_id.should == class_object_id
        end
      end

      shared_examples_for 'a wrapped target' do
        it 'exposes a Representor interface' do
          if @check_semantics
            representor.each_data_semantic.any? { |data_semantic| data_semantic.value == '1812' }.should be_true
          else
            representor.each_link_transition({conditions: 'can_do_anything'}).any? do |transition| 
              transition.name == 'deactivate' 
            end.should be_true
          end
        end
      end

      shared_examples_for 'a representor factory method' do
        it_behaves_like 'a wrapped target'

        it_behaves_like 'a memoized factory class'
      end
      
      shared_examples_for 'a representor factory' do
        describe '.build_representor' do
          let(:representor) { subject.build_representor(target, :drd) }
          
          before do
            @check_semantics = true
          end

          context 'with object target' do
            before do
              @target = :object
            end

            it_behaves_like 'a representor factory method'
          end

          context 'with hash target' do
            before do
              @target = {name: '1812'}
            end
            
            it_behaves_like 'a representor factory method'
          end 
        end

        describe '.build_state_representor' do
          let(:representor) { subject.build_state_representor(target, :drd, @options) }

          context 'with no options' do
            it 'raises an error' do
              expect { subject.build_state_representor(target, :drd) }.to raise_error(ArgumentError,
                /^No :state or :state_method option set in '\{\}'.*/)
            end
          end

          context 'with :state option' do
            before do
              @options = {state: 'activate'}
            end

            context 'with object target' do
              before do
                @target = :object
              end

              it_behaves_like 'a representor factory method'
            end

            context 'with hash target' do
              before do
                @target = {name: '1812'}
              end

              it_behaves_like 'a representor factory method'
            end
          end

          context 'with :state_method option' do
            before do
              @options = {state_method: :my_state}
            end

            context 'with object target' do
              before do
                @target = :object
                target.stub(:my_state).and_return('activate')
              end

              it_behaves_like 'a representor factory method'
            end

            context 'with hash target' do
              before do
                @target = {name: '1812'}
              end

              it_behaves_like 'a representor factory method'
            end
          end

          context 'with :state and :state_method options' do
            it 'raises an error' do
              options = {state: 'something', state_method: 'something_else'}
              expect { subject.build_state_representor(target, :drd, options) }.to raise_error(ArgumentError,
                /^Both :state and :state_method option set in '{:state=>"something", :state_method=>"something_else"}'.*/)
            end
          end
        end
      end

      context 'when extending a class' do
        let(:subject) do 
          simple_test_class.tap { |klass| klass.send(:extend, Factory) }
        end
       
        it_behaves_like 'a representor factory'
      end
      
      context 'when included in a class' do
        let(:subject) do
          simple_test_class.tap { |klass| klass.send(:include, Factory) }.new
        end

        it_behaves_like 'a representor factory'
      end
    end
  end
end
