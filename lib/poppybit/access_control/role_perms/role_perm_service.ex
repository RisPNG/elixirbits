defmodule Poppybit.AccessControl.RolePerms.RolePermService do
  require Ash.CodeInterface

  Ash.CodeInterface.define_interface(
    Poppybit.AccessControl.AccessControlService,
    Poppybit.AccessControl.RolePerm
  )
end
