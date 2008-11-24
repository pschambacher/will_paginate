require 'will_paginate/view_helpers/base'
require 'action_view'
require 'action_pack/version'
require 'will_paginate/view_helpers/link_renderer'

module WillPaginate
  module ViewHelpers
    # ActionView helpers for Rails integration
    module ActionView
      include WillPaginate::ViewHelpers::Base
      
      def will_paginate(collection = nil, options = {})
        options, collection = collection, nil if collection.is_a? Hash
        collection ||= infer_collection_from_controller

        super(collection, options.symbolize_keys)
      end
      
      def page_entries_info(collection = nil, options = {})
        options, collection = collection, nil if collection.is_a? Hash
        collection ||= infer_collection_from_controller
        
        super(collection, options.symbolize_keys)
      end
      
      # Wrapper for rendering pagination links at both top and bottom of a block
      # of content.
      # 
      #   <% paginated_section @posts do %>
      #     <ol id="posts">
      #       <% for post in @posts %>
      #         <li> ... </li>
      #       <% end %>
      #     </ol>
      #   <% end %>
      #
      # will result in:
      #
      #   <div class="pagination"> ... </div>
      #   <ol id="posts">
      #     ...
      #   </ol>
      #   <div class="pagination"> ... </div>
      #
      # Arguments are passed to a <tt>will_paginate</tt> call, so the same options
      # apply. Don't use the <tt>:id</tt> option; otherwise you'll finish with two
      # blocks of pagination links sharing the same ID (which is invalid HTML).
      def paginated_section(*args, &block)
        pagination = will_paginate(*args).to_s
        
        if ::ActionPack::VERSION::STRING.to_f >= 2.2
          concat pagination
          yield
          concat pagination
        else
          content = pagination + capture(&block) + pagination
          concat(content, block.binding)
        end
      end
      
    protected

      def infer_collection_from_controller
        collection_name = "@#{controller.controller_name}"
        collection = instance_variable_get(collection_name)
        raise ArgumentError, "The #{collection_name} variable appears to be empty. Did you " +
          "forget to pass the collection object for will_paginate?" if collection.nil?
        collection
      end
    end
  end
end

ActionView::Base.send :include, WillPaginate::ViewHelpers::ActionView

if defined?(ActionController::Base) and ActionController::Base.respond_to? :rescue_responses
  ActionController::Base.rescue_responses['WillPaginate::InvalidPage'] = :not_found
end

WillPaginate::ViewHelpers::LinkRenderer.class_eval do
  protected
  
  def default_url_params
    { :escape => false }
  end
  
  def url(page)
    @base_url_params ||= begin
      url_params = base_url_params
      merge_optional_params(url_params)
      url_params
    end
    
    url_params = @base_url_params.dup
    add_current_page_param(url_params, page)
    
    @template.url_for(url_params)
  end
  
  def base_url_params
    url_params = default_url_params
    # page links should preserve GET parameters
    symbolized_update(url_params, @template.params) if get_request?
    url_params
  end
  
  def merge_optional_params(url_params)
    symbolized_update(url_params, @options[:params]) if @options[:params]
  end
  
  def add_current_page_param(url_params, page)
    unless param_name.index(/[^\w-]/)
      url_params[param_name.to_sym] = page
    else
      page_param = (defined?(CGIMethods) ? CGIMethods : ActionController::AbstractRequest).
        parse_query_parameters(param_name + '=' + page.to_s)
      
      symbolized_update(url_params, page_param)
    end
  end
  
  def get_request?
    @template.request.get?
  end
end