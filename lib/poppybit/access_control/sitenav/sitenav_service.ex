defmodule Poppybit.AccessControl.Sitenav.SitenavService do
  require Ash.CodeInterface

  Ash.CodeInterface.define_interface(
    Poppybit.AccessControl.AccessControlService,
    Poppybit.AccessControl.Sitenav
  )
end
