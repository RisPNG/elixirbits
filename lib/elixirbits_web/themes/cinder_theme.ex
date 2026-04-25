defmodule ElixirbitsWeb.CinderTheme do
  @moduledoc false
  use Cinder.Theme

  set :container_class, "rounded-lg border border-base-300 bg-base-100"
  set :controls_class, "shadow-sm mb-6"
  set :table_wrapper_class, "overflow-x-auto"
  set :table_class, "w-full text-left [&_tbody_tr:nth-child(even)]:bg-base-200"
  set :thead_class, ""
  set :tbody_class, ""
  set :header_row_class, ""
  set :row_class, ""
  set :th_class, "px-3 py-2 text-left font-semibold text-base-content whitespace-nowrap"
  set :td_class, "px-3 py-2 text-base-content"
  set :empty_class, "text-center py-8 text-base-content/60"

  set :error_container_class,
      "flex items-center gap-2 p-4 rounded-md border bg-error/10 border-error/30 text-error"

  set :error_message_class, ""

  set :filter_container_class, "rounded-lg border border-base-300 bg-base-100 mb-6"
  set :filter_header_class, "p-6 pb-4 flex flex-row items-center justify-between"
  set :filter_title_class, "text-lg font-semibold text-base-content"

  set :filter_count_class,
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-primary text-primary-content"

  set :filter_clear_all_class,
      "inline-flex items-center justify-center px-2 py-1 rounded-md text-xs font-medium bg-transparent text-base-content hover:bg-base-200 transition-colors"

  set :filter_label_class, "text-sm font-medium text-base-content whitespace-nowrap pb-1"

  set :filter_inputs_class,
      "grid grid-cols-[repeat(auto-fit,minmax(14rem,1fr))] gap-x-4 gap-y-2 px-6 pb-6 min-h-11"

  set :filter_input_wrapper_class, "flex flex-col min-w-0"

  set :filter_clear_button_class,
      "inline-flex items-center justify-center px-2 py-1 rounded-md text-xs font-medium bg-transparent text-base-content hover:bg-base-200 transition-colors ml-2"

  set :filter_text_input_class,
      "block w-full px-3 py-2 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"

  set :filter_date_input_class,
      "block w-full px-3 py-2 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"

  set :filter_number_input_class,
      "block w-full px-3 py-2 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

  set :filter_select_input_class,
      "block w-full px-3 py-2 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"

  set :filter_select_container_class, "relative"

  set :filter_select_dropdown_class,
      "absolute z-50 w-full mt-1 bg-base-100 border border-base-300 rounded-lg shadow-lg max-h-60 overflow-auto"

  set :filter_select_option_class,
      "px-4 py-2 hover:bg-base-200 border-b border-base-300 last:border-b-0 cursor-pointer text-base-content"

  set :filter_select_label_class, "text-sm cursor-pointer select-none flex-1 text-base-content"
  set :filter_select_empty_class, "px-3 py-2 text-base-content/50 italic text-sm"
  set :filter_select_arrow_class, ""
  set :filter_select_placeholder_class, "text-base-content/40"

  set :filter_radio_group_container_class, "flex space-x-4 h-10 items-center"
  set :filter_radio_group_option_class, "flex items-center space-x-2"
  set :filter_radio_group_radio_class, "h-4 w-4 accent-primary"
  set :filter_radio_group_label_class, "text-sm cursor-pointer text-base-content"

  set :filter_checkbox_container_class, "flex items-center h-10"

  set :filter_checkbox_input_class,
      "h-4 w-4 rounded border border-base-300 accent-primary mr-2"

  set :filter_checkbox_label_class, "text-sm cursor-pointer text-base-content"

  set :filter_multiselect_container_class, "relative"

  set :filter_multiselect_dropdown_class,
      "absolute z-50 w-full mt-1 bg-base-100 border border-base-300 rounded-lg shadow-lg max-h-60 overflow-auto"

  set :filter_multiselect_option_class,
      "px-3 py-2 hover:bg-base-200 border-b border-base-300 last:border-b-0 cursor-pointer text-base-content"

  set :filter_multiselect_checkbox_class,
      "h-4 w-4 rounded border border-base-300 accent-primary mr-2"

  set :filter_multiselect_label_class,
      "text-sm cursor-pointer select-none flex-1 text-base-content"

  set :filter_multiselect_empty_class, "px-3 py-2 text-base-content/50 italic text-sm"

  set :filter_multicheckboxes_container_class, "space-y-2"
  set :filter_multicheckboxes_option_class, "flex items-center gap-2"

  set :filter_multicheckboxes_checkbox_class,
      "h-5 w-5 rounded border border-base-300 accent-primary"

  set :filter_multicheckboxes_label_class, "text-sm cursor-pointer text-base-content"

  set :filter_range_container_class, "flex items-center gap-2"
  set :filter_range_input_group_class, ""

  set :filter_range_separator_class,
      "flex items-center px-1 text-sm font-medium text-base-content/60"

  set :pagination_wrapper_class, "p-4"
  set :pagination_container_class, "flex items-center justify-between"
  set :pagination_info_class, "text-base-content/70 text-sm"
  set :pagination_count_class, "text-base-content/50 text-xs ml-2"
  set :pagination_nav_class, "flex items-center space-x-1"

  set :pagination_button_class,
      "inline-flex items-center justify-center px-3 py-1.5 rounded-md text-sm font-medium bg-primary/15 text-primary hover:bg-primary/25 transition-colors"

  set :pagination_current_class,
      "inline-flex items-center justify-center px-3 py-1.5 rounded-md text-sm font-medium bg-primary text-primary-content"

  set :page_size_container_class, "flex items-center space-x-2"
  set :page_size_label_class, "text-base-content/70 text-sm"

  set :page_size_dropdown_class,
      "inline-flex items-center justify-center px-3 py-1.5 rounded-md text-sm font-medium border border-base-content/30 text-base-content hover:bg-base-200 transition-colors cursor-pointer"

  set :page_size_dropdown_container_class,
      "bg-base-100 border border-base-300 rounded-lg shadow-lg"

  set :page_size_option_class,
      "w-full text-left px-3 py-2 text-sm hover:bg-base-200 cursor-pointer text-base-content"

  set :page_size_selected_class, "bg-primary text-primary-content"

  set :search_input_class,
      "block w-full pl-10 px-3 py-2 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"

  set :search_icon_class, "w-4 h-4"

  set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
  set :sort_arrow_wrapper_class, "inline-flex items-center"
  set :sort_asc_icon_class, "w-3 h-3 text-primary"
  set :sort_desc_icon_class, "w-3 h-3 text-primary"
  set :sort_none_icon_class, "w-3 h-3 text-base-content/60"

  set :loading_overlay_class, "absolute top-4 right-4"
  set :loading_container_class, "flex items-center text-sm text-primary"

  set :loading_spinner_class,
      "h-4 w-4 mr-2 rounded-full border-2 border-current border-t-transparent animate-spin"

  set :loading_spinner_circle_class, ""
  set :loading_spinner_path_class, ""

  set :list_container_class, "space-y-4 px-4"

  set :list_item_class,
      "rounded-lg border border-base-300 bg-base-100 p-6 shadow-sm text-base-content"

  set :list_item_clickable_class, "cursor-pointer hover:shadow-md transition-shadow"

  set :sort_container_class, "rounded-lg border border-base-300 bg-base-100"
  set :sort_controls_class, "p-4 flex flex-row items-center gap-3"
  set :sort_controls_label_class, "text-sm font-medium text-base-content"
  set :sort_buttons_class, "flex gap-2"

  set :sort_button_class,
      "inline-flex items-center justify-center px-3 py-1.5 rounded-md text-sm font-medium transition-colors"

  set :sort_button_active_class, "bg-primary text-primary-content hover:bg-primary/90"

  set :sort_button_inactive_class,
      "bg-transparent text-base-content hover:bg-base-200"

  set :sort_icon_class, "ml-1"
  set :sort_asc_icon, "↑"
  set :sort_desc_icon, "↓"

  set :grid_container_class, "grid gap-4 px-4"

  set :grid_item_class,
      "rounded-lg border border-base-300 bg-base-100 p-6 shadow-sm text-base-content"

  set :grid_item_clickable_class, "cursor-pointer hover:shadow-md transition-shadow"

  set :selection_checkbox_class, "h-4 w-4 rounded border border-base-300 accent-primary"
  set :selected_row_class, "bg-primary/5 even:bg-primary/10"
  set :grid_selection_overlay_class, "mb-2"
  set :selected_item_class, "ring-2 ring-primary"
  set :list_selection_container_class, "mb-2"
  set :bulk_actions_container_class, "flex flex-row gap-2 justify-end py-3 px-4"

  set :button_class,
      "inline-flex items-center justify-center px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-accent/40"

  set :button_primary_class, "bg-primary text-primary-content hover:bg-primary/90"
  set :button_secondary_class, "bg-neutral text-neutral-content hover:bg-neutral/90"
  set :button_danger_class, "bg-error text-error-content hover:bg-error/90"
  set :button_disabled_class, "opacity-50 pointer-events-none"
end
