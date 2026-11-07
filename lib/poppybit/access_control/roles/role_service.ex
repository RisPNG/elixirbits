defmodule Poppybit.AccessControl.Roles.RoleService do
  require Ash.CodeInterface

  Ash.CodeInterface.define_interface(
    Poppybit.AccessControl.AccessControlService,
    Poppybit.AccessControl.Role
  )
end
