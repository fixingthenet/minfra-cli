# frozen_string_literal: true

module Orchparty
  module Transformations
    class Mixin
      def transform(ast)
        ast.applications.transform_values! do |application|
          current = AST.application
          application._mix.each do |mixin_name|
            mixin = application._mixins[mixin_name] || ast._mixins[mixin_name]
            mixin = resolve_chart_name(mixin, application)
            current = current.deep_merge_concat(mixin)
          end
          transform_application(current.deep_merge_concat(application), ast)
        end
        ast
      end

      def resolve_chart_name(mixin, application)
        #            warn "ERROR: #{mixin} #{application}"
        if mixin.services[:_mixin_temp_name]
          mixin.services[application.name.to_s] = mixin.services.delete('_mixin_temp_name')
          mixin.services[application.name.to_s][:name] = application.name.to_s
          mixin._service_order.delete('_mixin_temp_name')
          mixin._service_order << application.name.to_s
        end
        mixin
      end

      def transform_application(application, ast)
        application.services = application.services.transform_values! do |service|
          current = AST.service
          service.delete(:_mix).compact.each do |mix|
            current = current.deep_merge_concat(resolve_mixin(mix, application, ast))
          rescue StandardError
            warn "problems with #{mix}"
            raise
          end
          current.deep_merge_concat(service)
        end
        application
      end

      def resolve_mixin(mix, application, ast)
        mixin = if mix.include? '.'
                  mixin_name, mixin_service_name = mix.split('.')
                  if ast._mixins[mixin_name]
                    ast._mixins[mixin_name]._mixins[mixin_service_name]
                  else
                    warn "ERROR: Could not find mixin '#{mixin_name}'."
                    exit 1
                  end
                else
                  application._mixins[mix]
                end
        if mixin.nil?
          warn "ERROR: Could not find mixin '#{mix}'."
          exit 1
        end
        transform_mixin(mixin, application, ast)
      end

      def transform_mixin(mixin, application, ast)
        current = AST.application_mixin

        mixin[:_mix].each do |mix|
          current = current.deep_merge_concat(resolve_mixin(mix, application, ast))
        end
        current.deep_merge_concat(mixin)
      end
    end
  end
end
