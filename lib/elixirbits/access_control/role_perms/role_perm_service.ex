defmodule Elixirbits.AccessControl.RolePerms.RolePermService do
  require Ash.CodeInterface

  Ash.CodeInterface.define_interface(
    Elixirbits.AccessControl.AccessControlService,
    Elixirbits.AccessControl.RolePerm
  )
end
