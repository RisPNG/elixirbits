defmodule PoppybitWeb.IndexLive.Index do
  use PoppybitWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign(:organization, Poppybit.Organizations.OrganizationService.current_organization!())}
  end
end
