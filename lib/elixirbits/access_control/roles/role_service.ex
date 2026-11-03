defmodule Elixirbits.AccessControl.Roles.RoleService do
  require Ash.CodeInterface

  Ash.CodeInterface.define_interface(
    Elixirbits.AccessControl.AccessControlService,
    Elixirbits.AccessControl.Role
  )
end
