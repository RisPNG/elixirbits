defmodule ElixirbitsWeb.CinderTheme do
  @moduledoc false
  use Cinder.Theme

  set :container_class, ""
  set :controls_class, "gap-6 mb-6"
  set :table_wrapper_class, "listing-surface overflow-x-auto"
  set :table_class, "listing-table"
  set :thead_class, ""
  set :tbody_class, ""
  set :header_row_class, ""
  set :row_class, ""
  set :th_class, "listing-heading"
  set :td_class, "listing-cell"
  set :empty_class, "text-center py-8 text-subcontent"

  set :error_container_class,
      "grid grid-cols-[1fr] p-4 rounded-default border bg-primary overlay-dark border-error text-error"

  set :error_message_class, ""

  set :filter_container_class, "listing-surface"
  set :filter_header_class, "p-6 pb-4 grid grid-cols-[1fr_max-content] items-center gap-2"
  set :filter_title_class, "text-lg font-semibold text-content"

  set :filter_toggle_class,
      "cursor-pointer select-none inline-grid grid-cols-[1rem_max-content_max-content] items-center gap-1 hover:overlay-dark"

  set :filter_count_class,
      "inline-grid place-items-center px-2 py-0.5 rounded-full text-xs font-medium bg-brand text-content"

  set :filter_clear_all_class,
      "inline-grid place-items-center px-2 py-1 rounded-default text-xs font-medium bg-transparent text-content hover:overlay-dark transition-colors"

  set :filter_label_class, "text-sm font-medium text-content whitespace-nowrap pb-1"

  set :filter_inputs_class,
      "grid grid-cols-[1fr_1fr] subgap-4 gap-y-2 px-6 pb-6 min-h-11"

  set :filter_input_wrapper_class, "flex flex-col min-w-0"

  set :filter_clear_button_class,
      "inline-grid place-items-center px-2 py-1 rounded-default text-xs font-medium bg-transparent text-content hover:overlay-dark transition-colors"

  set :filter_text_input_class,
      "block w-full px-3 py-2 rounded-default border border-outline bg-transparent text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :filter_date_input_class,
      "block w-full px-3 py-2 rounded-default border border-outline bg-transparent text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :filter_number_input_class,
      "block w-full px-3 py-2 rounded-default border border-outline bg-transparent text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

  set :filter_select_input_class,
      "grid grid-cols-[1fr] w-full px-3 py-2 rounded-default border border-outline bg-transparent text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :filter_select_container_class, "relative"

  set :filter_select_dropdown_class,
      "absolute z-50 w-full mt-1 bg-primary border border-outline rounded-default shadow-lg max-h-60 overflow-auto"

  set :filter_select_option_class,
      "px-4 py-2 hover:overlay-dark border-b border-outline last:border-b-0 cursor-pointer text-content"

  set :filter_select_label_class, "text-sm cursor-pointer select-none text-content"
  set :filter_select_empty_class, "px-3 py-2 text-subcontent italic text-sm"
  set :filter_select_arrow_class, ""
  set :filter_select_placeholder_class, "text-subcontent"

  set :filter_radio_group_container_class, "grid grid-cols-[1fr] gap-2 min-h-10 items-center"
  set :filter_radio_group_option_class, "grid grid-cols-[1rem_1fr] items-center gap-2"

  set :filter_radio_group_radio_class,
      "appearance-none h-4 w-4 rounded-full border border-outline bg-transparent checked:border-brand checked:bg-brand checked:bg-control-radio focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary"

  set :filter_radio_group_label_class, "text-sm cursor-pointer text-content"

  set :filter_checkbox_container_class, "grid grid-cols-[1rem_1fr] items-center gap-2 min-h-10"

  set :filter_checkbox_input_class,
      "appearance-none h-4 w-4 rounded-default border border-outline bg-transparent checked:border-brand checked:bg-brand checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%] focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary"

  set :filter_checkbox_label_class, "text-sm cursor-pointer text-content"

  set :filter_multiselect_container_class, "relative"

  set :filter_multiselect_dropdown_class,
      "absolute z-50 w-full mt-1 bg-primary border border-outline rounded-default shadow-lg max-h-60 overflow-auto"

  set :filter_multiselect_option_class,
      "px-3 py-2 hover:overlay-dark border-b border-outline last:border-b-0 cursor-pointer text-content"

  set :filter_multiselect_checkbox_class,
      "appearance-none h-4 w-4 rounded-default border border-outline bg-transparent checked:border-brand checked:bg-brand checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%] focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary"

  set :filter_multiselect_label_class,
      "text-sm cursor-pointer select-none text-content"

  set :filter_multiselect_empty_class, "px-3 py-2 text-subcontent italic text-sm"

  set :filter_multicheckboxes_container_class, "space-y-2"
  set :filter_multicheckboxes_option_class, "grid grid-cols-[1.25rem_1fr] items-center gap-2"

  set :filter_multicheckboxes_checkbox_class,
      "appearance-none h-5 w-5 rounded-default border border-outline bg-transparent checked:border-brand checked:bg-brand checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%] focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary"

  set :filter_multicheckboxes_label_class, "text-sm cursor-pointer text-content"

  set :filter_range_container_class, "grid grid-cols-[1fr_1rem_1fr] items-center gap-2"
  set :filter_range_input_group_class, "min-w-0"

  set :filter_range_separator_class,
      "grid place-items-center text-sm font-medium text-subcontent"

  set :pagination_wrapper_class, "p-4"
  set :pagination_container_class, "grid grid-cols-[1fr] gap-3"
  set :pagination_info_class, "text-subcontent text-sm"
  set :pagination_count_class, "text-subcontent text-xs ml-2"

  set :pagination_nav_class,
      "grid grid-cols-[max-content] grid-flow-col auto-cols-max items-center justify-end gap-2 [&>button[phx-value-page]]:text-2xl [&>button[phx-value-page]]:leading-none"

  set :pagination_button_class,
      "inline-grid place-items-center min-h-11 min-w-11 px-3 rounded-default text-sm font-medium button-neutral transition-colors"

  set :pagination_current_class,
      "inline-grid place-items-center min-h-11 min-w-11 px-3 rounded-default border border-outline text-sm font-medium bg-brand text-content hover:overlay-dark"

  set :page_size_container_class, "grid grid-cols-[max-content] items-center"
  set :page_size_label_class, "text-subcontent text-sm"

  set :page_size_dropdown_class,
      "inline-grid grid-cols-[max-content_1rem] items-center gap-2 min-h-11 px-3 rounded-default text-sm font-medium border border-outline text-content hover:overlay-dark transition-colors cursor-pointer"

  set :page_size_dropdown_container_class,
      "bg-primary border border-outline rounded-default shadow-lg"

  set :page_size_option_class,
      "w-full text-left px-3 py-2 text-sm hover:overlay-dark cursor-pointer text-content"

  set :page_size_selected_class, "bg-brand text-content"

  set :search_input_class,
      "block w-full pl-10 px-3 py-2 rounded-default border border-outline bg-transparent text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :search_icon_class, "w-4 h-4"

  set :sort_indicator_class, "inline-grid place-items-center align-baseline"
  set :sort_arrow_wrapper_class, "inline-grid place-items-center"
  set :sort_asc_icon_class, "w-3 h-3 text-brand"
  set :sort_desc_icon_class, "w-3 h-3 text-brand"
  set :sort_none_icon_class, "w-3 h-3 text-subcontent"

  set :loading_overlay_class, "absolute top-4 right-4"

  set :loading_container_class,
      "grid grid-cols-[1rem_max-content] items-center gap-2 text-sm text-brand"

  set :loading_spinner_class,
      "h-4 w-4 rounded-full border-2 border-current border-t-transparent animate-spin"

  set :loading_spinner_circle_class, ""
  set :loading_spinner_path_class, ""

  set :list_container_class, "space-y-4"

  set :list_item_class,
      "listing-surface p-6 text-content"

  set :list_item_clickable_class, "cursor-pointer hover:overlay-dark transition-colors"

  set :sort_container_class, "listing-surface"
  set :sort_controls_class, "p-4 grid grid-cols-[max-content_1fr] items-center gap-3"
  set :sort_controls_label_class, "text-sm font-medium text-content"

  set :sort_buttons_class,
      "grid grid-cols-[repeat(4,max-content)] items-center justify-start gap-2"

  set :sort_button_class,
      "inline-grid grid-cols-[max-content_0.75rem] items-center gap-1 px-3 py-1.5 rounded-default text-sm font-medium hover:overlay-dark transition-colors"

  set :sort_button_active_class, "bg-brand text-content"

  set :sort_button_inactive_class,
      "bg-transparent text-content"

  set :grid_container_class, "grid gap-4"

  set :grid_item_class,
      "listing-surface p-6 text-content"

  set :grid_item_clickable_class, "cursor-pointer hover:overlay-dark transition-colors"

  set :selection_checkbox_class,
      "appearance-none h-4 w-4 rounded-default border border-outline bg-transparent checked:border-brand checked:bg-brand checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%] focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary"

  set :selected_row_class, "bg-primary even:overlay-dark"
  set :grid_selection_overlay_class, "mb-2"
  set :selected_item_class, "ring-2 ring-primary"
  set :list_selection_container_class, "mb-2"

  set :bulk_actions_container_class,
      "grid grid-cols-[repeat(4,max-content)] gap-2 justify-end py-3 px-4"

  set :button_class,
      "inline-grid place-items-center min-h-11 px-4 py-2 rounded-default text-sm font-medium whitespace-nowrap transition-colors focus:outline-none focus:ring-2 focus:ring-brand"

  set :button_primary_class, "button-primary"
  set :button_secondary_class, "button-neutral"
  set :button_danger_class, "button-danger"
  set :button_disabled_class, "overlay-dark text-subcontent pointer-events-none"
end
