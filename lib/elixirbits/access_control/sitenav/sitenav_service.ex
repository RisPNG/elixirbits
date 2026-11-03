defmodule Elixirbits.AccessControl.Sitenav.SitenavService do
  require Ash.CodeInterface

  Ash.CodeInterface.define_interface(
    Elixirbits.AccessControl.AccessControlService,
    Elixirbits.AccessControl.Sitenav
  )
end
