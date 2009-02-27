
require 'evil'

# bwahaha, make evil even more evil by removing all its sanity checks
class Class
  remove_method :to_internal_type
  def to_internal_type
    RubyInternal::T_OBJECT
  end
end

module Kernel
  # grr, why isn't this standard
  unless method_defined? :singleton_class
    def singleton_class
      class << self
        self
      end
    end
  end
end

module Prefer
  class << self
    def mixins(mod)
      mod.ancestors[1..-1].take_while { |ancestor|
        not ancestor.is_a?(Class)
      }
    end
  
    def reset_mixins(mod, mixins)
      # evil: remove current mixins by resetting superclass 
      sup = mod.superclass
      mod.superclass = sup
      
      # include given mixins
      mod.module_eval {
        mixins.reverse.each { |mixin|
          include mixin
        }
      }
    end
  
    def extended(source_module)
      preferences = Hash.new

      #
      # define methods for the extendee
      #
      source_module.singleton_class.module_eval {
        #
        # prefer
        #
        define_method(:prefer) { |hash|
          preferences.merge!(hash)
        }

        #
        # method_added is defined via lambda for recursion avoidance
        #
        method_added = lambda { |name|
          original_method = source_module.instance_method(name)

          #
          # temporarily remove method_added to avoid recursion
          #
          source_module.singleton_class.instance_eval {
            remove_method(:method_added)
          }

          begin
            source_module.instance_eval {
              #
              # The new method changes the ancestry order of mixins,
              # then executes the original method, then restores the
              # ancestry.
              #
              define_method(name) { |*args, &block|
                original_mixin_memo = Hash.new
                preferences.each_pair { |preferred_mixin, target|
                  original_mixins = Prefer.mixins(target)
                  original_mixin_memo.merge!(target => original_mixins)
                  new_mixins = original_mixins.dup
                  new_mixins.delete(preferred_mixin)
                  new_mixins.unshift(preferred_mixin)
                  Prefer.reset_mixins(target, new_mixins)
                }
                begin
                  original_method.bind(self).call(*args, &block)
                ensure
                  original_mixin_memo.each_pair { |target, mixins|
                    Prefer.reset_mixins(target, mixins)
                  }
                end
              }
            }
          ensure
            #
            # restore method_added -- was removed to avoid recursion
            #
            source_module.singleton_class.instance_eval {
              define_method(:method_added, &method_added)
            }
          end
        }

        #
        # define the actual method_added method for the first time
        #
        define_method(:method_added, &method_added)
      }
    end
  end
end
