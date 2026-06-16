defmodule ElixirbitsWeb.CinderTheme do
  @moduledoc false
  use Cinder.Theme

  set :container_class, "rounded-lg border border-primary-alt bg-primary"
  set :controls_class, "shadow-sm mb-6"
  set :table_wrapper_class, "overflow-x-auto"
  set :table_class, "w-full text-left [&_tbody_tr:nth-child(even)]:bg-primary-alt"
  set :thead_class, ""
  set :tbody_class, ""
  set :header_row_class, ""
  set :row_class, ""
  set :th_class, "px-3 py-2 text-left font-semibold text-content whitespace-nowrap"
  set :td_class, "px-3 py-2 text-content"
  set :empty_class, "text-center py-8 text-subcontent"

  set :error_container_class,
      "flex items-center gap-2 p-4 rounded-md border bg-primary-alt border-error text-error"

  set :error_message_class, ""

  set :filter_container_class, "rounded-lg border border-primary-alt bg-primary mb-6"
  set :filter_header_class, "p-6 pb-4 flex flex-row items-center justify-between"
  set :filter_title_class, "text-lg font-semibold text-content"

  set :filter_count_class,
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-brand text-content-alt"

  set :filter_clear_all_class,
      "inline-flex items-center justify-center px-2 py-1 rounded-md text-xs font-medium bg-transparent text-content hover:bg-primary-alt transition-colors"

  set :filter_label_class, "text-sm font-medium text-content whitespace-nowrap pb-1"

  set :filter_inputs_class,
      "grid grid-cols-[repeat(auto-fit,minmax(14rem,1fr))] gap-x-4 gap-y-2 px-6 pb-6 min-h-11"

  set :filter_input_wrapper_class, "flex flex-col min-w-0"

  set :filter_clear_button_class,
      "inline-flex items-center justify-center px-2 py-1 rounded-md text-xs font-medium bg-transparent text-content hover:bg-primary-alt transition-colors ml-2"

  set :filter_text_input_class,
      "block w-full px-3 py-2 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :filter_date_input_class,
      "block w-full px-3 py-2 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :filter_number_input_class,
      "block w-full px-3 py-2 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

  set :filter_select_input_class,
      "block w-full px-3 py-2 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :filter_select_container_class, "relative"

  set :filter_select_dropdown_class,
      "absolute z-50 w-full mt-1 bg-primary border border-primary-alt rounded-lg shadow-lg max-h-60 overflow-auto"

  set :filter_select_option_class,
      "px-4 py-2 hover:bg-primary-alt border-b border-primary-alt last:border-b-0 cursor-pointer text-content"

  set :filter_select_label_class, "text-sm cursor-pointer select-none flex-1 text-content"
  set :filter_select_empty_class, "px-3 py-2 text-subcontent italic text-sm"
  set :filter_select_arrow_class, ""
  set :filter_select_placeholder_class, "text-subcontent"

  set :filter_radio_group_container_class, "flex space-x-4 h-10 items-center"
  set :filter_radio_group_option_class, "flex items-center space-x-2"
  set :filter_radio_group_radio_class, "h-4 w-4 accent-primary"
  set :filter_radio_group_label_class, "text-sm cursor-pointer text-content"

  set :filter_checkbox_container_class, "flex items-center h-10"

  set :filter_checkbox_input_class,
      "h-4 w-4 rounded border border-primary-alt accent-primary mr-2"

  set :filter_checkbox_label_class, "text-sm cursor-pointer text-content"

  set :filter_multiselect_container_class, "relative"

  set :filter_multiselect_dropdown_class,
      "absolute z-50 w-full mt-1 bg-primary border border-primary-alt rounded-lg shadow-lg max-h-60 overflow-auto"

  set :filter_multiselect_option_class,
      "px-3 py-2 hover:bg-primary-alt border-b border-primary-alt last:border-b-0 cursor-pointer text-content"

  set :filter_multiselect_checkbox_class,
      "h-4 w-4 rounded border border-primary-alt accent-primary mr-2"

  set :filter_multiselect_label_class,
      "text-sm cursor-pointer select-none flex-1 text-content"

  set :filter_multiselect_empty_class, "px-3 py-2 text-subcontent italic text-sm"

  set :filter_multicheckboxes_container_class, "space-y-2"
  set :filter_multicheckboxes_option_class, "flex items-center gap-2"

  set :filter_multicheckboxes_checkbox_class,
      "h-5 w-5 rounded border border-primary-alt accent-primary"

  set :filter_multicheckboxes_label_class, "text-sm cursor-pointer text-content"

  set :filter_range_container_class, "flex items-center gap-2"
  set :filter_range_input_group_class, ""

  set :filter_range_separator_class,
      "flex items-center px-1 text-sm font-medium text-subcontent"

  set :pagination_wrapper_class, "p-4"
  set :pagination_container_class, "flex items-center justify-between"
  set :pagination_info_class, "text-subcontent text-sm"
  set :pagination_count_class, "text-subcontent text-xs ml-2"
  set :pagination_nav_class, "flex items-center space-x-1"

  set :pagination_button_class,
      "inline-flex items-center justify-center px-3 py-1.5 rounded-md text-sm font-medium bg-primary-alt text-brand hover:bg-brand hover:text-content-alt transition-colors"

  set :pagination_current_class,
      "inline-flex items-center justify-center px-3 py-1.5 rounded-md text-sm font-medium bg-brand text-content-alt"

  set :page_size_container_class, "flex items-center space-x-2"
  set :page_size_label_class, "text-subcontent text-sm"

  set :page_size_dropdown_class,
      "inline-flex items-center justify-center px-3 py-1.5 rounded-md text-sm font-medium border border-subcontent text-content hover:bg-primary-alt transition-colors cursor-pointer"

  set :page_size_dropdown_container_class,
      "bg-primary border border-primary-alt rounded-lg shadow-lg"

  set :page_size_option_class,
      "w-full text-left px-3 py-2 text-sm hover:bg-primary-alt cursor-pointer text-content"

  set :page_size_selected_class, "bg-brand text-content-alt"

  set :search_input_class,
      "block w-full pl-10 px-3 py-2 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :search_icon_class, "w-4 h-4"

  set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
  set :sort_arrow_wrapper_class, "inline-flex items-center"
  set :sort_asc_icon_class, "w-3 h-3 text-brand"
  set :sort_desc_icon_class, "w-3 h-3 text-brand"
  set :sort_none_icon_class, "w-3 h-3 text-subcontent"

  set :loading_overlay_class, "absolute top-4 right-4"
  set :loading_container_class, "flex items-center text-sm text-brand"

  set :loading_spinner_class,
      "h-4 w-4 mr-2 rounded-full border-2 border-current border-t-transparent animate-spin"

  set :loading_spinner_circle_class, ""
  set :loading_spinner_path_class, ""

  set :list_container_class, "space-y-4 px-4"

  set :list_item_class,
      "rounded-lg border border-primary-alt bg-primary p-6 shadow-sm text-content"

  set :list_item_clickable_class, "cursor-pointer hover:shadow-md transition-shadow"

  set :sort_container_class, "rounded-lg border border-primary-alt bg-primary"
  set :sort_controls_class, "p-4 flex flex-row items-center gap-3"
  set :sort_controls_label_class, "text-sm font-medium text-content"
  set :sort_buttons_class, "flex gap-2"

  set :sort_button_class,
      "inline-flex items-center justify-center px-3 py-1.5 rounded-md text-sm font-medium transition-colors"

  set :sort_button_active_class, "bg-brand text-content-alt hover:bg-brand-alt"

  set :sort_button_inactive_class,
      "bg-transparent text-content hover:bg-primary-alt"

  set :sort_icon_class, "ml-1"
  set :sort_asc_icon, "↑"
  set :sort_desc_icon, "↓"

  set :grid_container_class, "grid gap-4 px-4"

  set :grid_item_class,
      "rounded-lg border border-primary-alt bg-primary p-6 shadow-sm text-content"

  set :grid_item_clickable_class, "cursor-pointer hover:shadow-md transition-shadow"

  set :selection_checkbox_class, "h-4 w-4 rounded border border-primary-alt accent-primary"
  set :selected_row_class, "bg-primary even:bg-primary-alt"
  set :grid_selection_overlay_class, "mb-2"
  set :selected_item_class, "ring-2 ring-primary"
  set :list_selection_container_class, "mb-2"
  set :bulk_actions_container_class, "flex flex-row gap-2 justify-end py-3 px-4"

  set :button_class,
      "inline-flex items-center justify-center px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-brand"

  set :button_primary_class, "bg-brand text-content-alt hover:bg-brand-alt"
  set :button_secondary_class, "bg-primary-alt text-content hover:bg-primary-alt"
  set :button_danger_class, "bg-error text-content-alt hover:bg-error-alt"
  set :button_disabled_class, "opacity-50 pointer-events-none"
end
