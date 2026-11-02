defmodule Elixirbits.AuditLog do
  require Ash.Query

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.AccessControl.ResourcePolicy
  alias Ash.Changeset.ManagedRelationshipHelpers
  alias AshPaperTrail.Resource.Info, as: PaperTrail

  def history(resource, id, actor, opts \\ []) do
    definition = audit_definition(resource, opts)
    system? = match?(%{system: true}, actor)
    permissions = if not system?, do: Permissions.load(actor)

    scope_paths =
      resource
      |> ResourcePolicy.scopes(:update)
      |> Enum.filter(&is_nil(&1.attribute))
      |> Enum.flat_map(& &1.paths)

    path =
      Enum.find(scope_paths, fn path ->
        matches? =
          is_nil(opts[:path]) or opts[:path] == path or
            String.starts_with?(opts[:path], path <> "/")

        matches? and (system? or Permissions.can?(permissions, path, :update))
      end)

    if system? or not is_nil(path) or scope_paths == [] do
      read_action = opts[:read_action] || Ash.Resource.Info.primary_action!(resource, :read).name
      query = Ash.Query.for_read(resource, read_action, %{}, actor: actor)
      loads = Enum.map(definition.relationships, & &1.name)

      record_result =
        if is_nil(id),
          do: Ash.read_one(query, actor: actor, load: loads),
          else:
            Ash.get(resource, id,
              action: read_action,
              actor: actor,
              load: loads,
              not_found_error?: false
            )

      with {:ok, record} when not is_nil(record) <- record_result do
        native_access? =
          system? or not is_nil(path) or
            (not is_nil(definition.action) and
               Ash.can?(
                 Ash.Changeset.for_update(record, definition.action.name, %{}),
                 actor,
                 maybe_is: false
               ))

        if native_access? do
          with {:ok, events} <- recorded_changes(record, definition, actor) do
            current = capture_state(record, definition)

            groups =
              events
              |> Enum.sort_by(
                &{DateTime.to_unix(&1.version.version_inserted_at, :microsecond), &1.id}
              )
              |> Enum.group_by(& &1.operation_id)
              |> Map.values()
              |> Enum.sort_by(fn group ->
                event = List.last(group)
                {DateTime.to_unix(event.version.version_inserted_at, :microsecond), event.id}
              end)

            {revisions, _state} =
              Enum.map_reduce(groups, %{attributes: %{}, related: %{}}, fn group, before ->
                after_state =
                  Enum.reduce(group, before, fn event, state ->
                    if is_nil(event.relationship) do
                      %{state | attributes: Map.merge(state.attributes, event.values)}
                    else
                      children =
                        state.related
                        |> Map.get(event.relationship, %{})
                        |> Map.reject(fn {_key, values} ->
                          Enum.all?(event.source_key, fn {field, value} ->
                            Map.fetch(values, field) == {:ok, value}
                          end)
                        end)

                      children =
                        if event.version.version_action_type == :destroy or not event.related? do
                          Map.delete(children, event.key)
                        else
                          Map.put(children, event.key, event.values)
                        end

                      %{state | related: Map.put(state.related, event.relationship, children)}
                    end
                  end)

                event = Enum.find(group, &is_nil(&1.relationship)) || List.last(group)
                version = event.version

                revision = %{
                  id: event.id,
                  at: List.last(group).version.version_inserted_at,
                  author: Map.get(version, :actor_name) || "Unknown",
                  action: version.version_action_type,
                  restored_from_version_id: Map.get(version, :restored_from_version_id),
                  fields: compare_versions(definition, before, after_state),
                  current_fields: compare_versions(definition, after_state, current),
                  before_state: before,
                  state: after_state,
                  definition: definition
                }

                {revision, after_state}
              end)

            can_restore? =
              not is_nil(definition.action) and
                (system? or
                   (not is_nil(path) and
                      Enum.all?([:create, :read, :update, :delete], fn capability ->
                        Permissions.can?(permissions, path, capability)
                      end)))

            {:ok,
             %{
               record: record,
               title: Phoenix.Naming.humanize(Ash.Resource.Info.short_name(resource)),
               path: path,
               current: current,
               revisions: Enum.reverse(revisions),
               can_restore?: can_restore?,
               definition: definition
             }}
          end
        else
          {:error, :forbidden}
        end
      else
        {:ok, nil} -> {:error, :not_found}
        error -> error
      end
    else
      {:error, :forbidden}
    end
  end

  def revision_record(record, revision, side \\ :previous, opts \\ [])
      when side in [:previous, :current] do
    definition = revision.definition
    state = if side == :previous, do: revision.state, else: capture_state(record, definition)
    before_state = if side == :previous, do: revision.before_state, else: revision.state
    fields = if side == :previous, do: revision.fields, else: revision.current_fields
    preserved = Keyword.get(opts, :preserve_fields, [])

    record =
      Enum.reduce(definition.attributes, record, fn attribute, record ->
        if attribute.name in preserved or attribute.sensitive? do
          record
        else
          case Map.fetch(state.attributes, to_string(attribute.name)) do
            {:ok, value} ->
              {:ok, value} =
                Ash.Type.cast_from_embedded(attribute.type, value, attribute.constraints)

              Map.put(record, attribute.name, value)

            :error ->
              record
          end
        end
      end)

    {record, form_relationships} =
      Enum.reduce(definition.relationships, {record, %{}}, fn relationship, {record, forms} ->
        saved_children = Map.get(state.related, relationship.name, %{})
        primary_key = Ash.Resource.Info.primary_key(relationship.resource)

        positions =
          saved_children
          |> ordered_relationship_snapshots(relationship)
          |> Enum.with_index()
          |> Map.new(fn {{key, _values}, index} -> {key, index} end)

        removed_keys =
          for field <- fields,
              field.relationship == relationship.name and field.status == :changed and
                not field.after_present?,
              do: field.record_key

        removed_children =
          before_state.related
          |> Map.get(relationship.name, %{})
          |> Map.take(removed_keys)
          |> Map.reject(fn {_key, values} ->
            Enum.any?(saved_children, fn {_key, saved} ->
              Enum.all?(primary_key, fn key ->
                Map.fetch!(values, to_string(key)) == Map.fetch!(saved, to_string(key))
              end)
            end)
          end)

        children =
          removed_children
          |> Map.merge(saved_children)
          |> ordered_relationship_snapshots(relationship)
          |> Enum.map(fn {key, values} ->
            removed? = not Map.has_key?(saved_children, key)

            child =
              Enum.reduce(relationship.attributes, struct(relationship.resource), fn attribute,
                                                                                     child ->
                value =
                  if removed? and attribute in relationship.fields and
                       attribute.name not in relationship.identity_fields,
                     do: {:ok, nil},
                     else: Map.fetch(values, to_string(attribute.name))

                case value do
                  {:ok, value} when not attribute.sensitive? ->
                    {:ok, value} =
                      Ash.Type.cast_from_embedded(attribute.type, value, attribute.constraints)

                    Map.put(child, attribute.name, value)

                  _ ->
                    child
                end
              end)

            changed =
              for field <- fields,
                  field.relationship == relationship.name and field.record_key == key and
                    field.status == :changed,
                  into: MapSet.new(),
                  do: field.attribute

            Ash.Resource.set_metadata(child, %{
              audit_record_key: key,
              audit_position: Map.get(positions, key),
              audit_recorded_fields: MapSet.new(Map.keys(values)),
              audit_changed_fields: changed,
              audit_change_side: if(removed?, do: :previous, else: side),
              audit_removed?: removed?
            })
          end)

        {removed_children, saved_children} =
          Enum.split_with(children, &Ash.Resource.get_metadata(&1, :audit_removed?))

        value =
          if relationship.relationship.cardinality == :many,
            do: saved_children,
            else: List.first(saved_children)

        form_value =
          if relationship.relationship.cardinality == :many do
            removed_by_key =
              Map.new(removed_children, fn child ->
                {Ash.Resource.get_metadata(child, :audit_record_key), child}
              end)

            before_state.related
            |> Map.get(relationship.name, %{})
            |> ordered_relationship_snapshots(relationship)
            |> Enum.with_index()
            |> Enum.reduce(saved_children, fn {{key, _values}, index}, children ->
              case Map.fetch(removed_by_key, key) do
                {:ok, child} -> List.insert_at(children, index, child)
                :error -> children
              end
            end)
          else
            value || List.first(removed_children)
          end

        {Map.put(record, relationship.name, value), Map.put(forms, relationship.name, form_value)}
      end)

    changed =
      for field <- fields,
          is_nil(field.relationship) and field.status == :changed,
          into: MapSet.new(),
          do: field.attribute

    Ash.Resource.set_metadata(record, %{
      audit_changed_fields: changed,
      audit_change_side: side,
      audit_form_relationships: form_relationships
    })
  end

  def preview(resource, id, version_id, actor, opts \\ []) do
    with {:ok, history} <- history(resource, id, actor, opts),
         true <- history.can_restore?,
         revision when not is_nil(revision) <-
           Enum.find(history.revisions, &(&1.id == version_id)) do
      {:ok, compare_versions(history.definition, history.current, revision.state)}
    else
      false -> {:error, :forbidden}
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def restore(resource, id, version_id, actor, opts \\ []) do
    with {:ok, history} <- history(resource, id, actor, opts),
         true <- history.can_restore?,
         revision when not is_nil(revision) <-
           Enum.find(history.revisions, &(&1.id == version_id)) do
      definition = history.definition
      changes = compare_versions(definition, history.current, revision.state)

      params =
        changes
        |> Enum.filter(&(is_nil(&1.relationship) and &1.restorable? and &1.status == :changed))
        |> Map.new(fn field ->
          {field.attribute, Map.fetch!(revision.state.attributes, to_string(field.attribute))}
        end)

      params =
        Enum.reduce(definition.relationships, params, fn relationship, params ->
          current = Map.get(history.current.related, relationship.name, %{})
          desired = Map.get(revision.state.related, relationship.name, %{})

          changed? =
            Enum.sort(Map.keys(current)) != Enum.sort(Map.keys(desired)) or
              Enum.any?(
                changes,
                &(&1.relationship == relationship.name and &1.status == :changed)
              )

          if changed? do
            values =
              desired
              |> ordered_relationship_snapshots(relationship)
              |> Enum.map(fn {key, attributes} ->
                action =
                  if Map.has_key?(current, key),
                    do: relationship.update_action,
                    else: relationship.create_action

                accepted =
                  if action,
                    do: Ash.Resource.Info.action(relationship.resource, action).accept,
                    else: []

                fields = Enum.map(accepted ++ relationship.identity_fields, &to_string/1)
                attributes = Map.take(attributes, fields)

                attributes =
                  case Map.fetch(current, key) do
                    {:ok, current_attributes} ->
                      keys =
                        Ash.Resource.Info.primary_key(relationship.resource)
                        |> Enum.map(&to_string/1)

                      Map.merge(attributes, Map.take(current_attributes, keys))

                    :error ->
                      attributes
                  end

                case relationship.argument.type do
                  type when type in [Ash.Type.Map, {:array, Ash.Type.Map}] ->
                    attributes

                  _ ->
                    key =
                      relationship.manage[:value_is_key] ||
                        List.first(relationship.identity_fields)

                    Map.get(attributes, to_string(key))
                end
              end)

            value =
              if match?({:array, _}, relationship.argument.type),
                do: values,
                else: List.first(values)

            Map.put(params, relationship.argument.name, value)
          else
            params
          end
        end)

      Ash.update(history.record, params,
        action: definition.action.name,
        actor: actor,
        context: %{shared: %{paper_trail_metadata: %{restored_from_version_id: version_id}}}
      )
    else
      false -> {:error, :forbidden}
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp audit_definition(resource, opts) do
    action =
      if opts[:update_action] do
        Ash.Resource.Info.action(resource, opts[:update_action], :update)
      else
        Ash.Resource.Info.action(resource, :restore, :update) ||
          Ash.Resource.Info.primary_action(resource, :update) ||
          Ash.Resource.Info.action(resource, :update, :update)
      end

    attributes = Ash.Resource.Info.attributes(resource)
    ignored = PaperTrail.ignore_attributes(resource)

    fields =
      Enum.filter(attributes, fn attribute ->
        attribute.writable? and not attribute.primary_key? and
          (attribute.name not in ignored or attribute.sensitive?)
      end)

    relationships =
      resource
      |> Ash.Resource.Info.action_changes(action)
      |> Enum.flat_map(fn
        %{change: {Ash.Resource.Change.ManageRelationship, options}} ->
          relationship = Ash.Resource.Info.relationship(resource, options[:relationship])
          argument = Enum.find(action.arguments, &(&1.name == options[:argument]))

          if argument && relationship.type in [:has_many, :has_one] &&
               AshPaperTrail.Resource in Spark.extensions(relationship.destination) do
            manage = options[:opts] || []

            defaults =
              if manage[:type],
                do: Ash.Changeset.manage_relationship_opts(manage[:type]),
                else: []

            manage =
              ManagedRelationshipHelpers.sanitize_opts(
                relationship,
                Keyword.merge(defaults, manage)
              )

            create_action =
              manage
              |> ManagedRelationshipHelpers.on_no_match_destination_actions(relationship)
              |> List.wrap()
              |> Enum.find_value(fn
                {:destination, name} -> name
                _ -> nil
              end)

            update_action =
              manage
              |> ManagedRelationshipHelpers.on_match_destination_actions(relationship)
              |> List.wrap()
              |> Enum.find_value(fn
                {:destination, name} -> name
                _ -> nil
              end)

            identity_fields =
              case List.first(manage[:use_identities] || []) do
                nil -> Ash.Resource.Info.primary_key(relationship.destination)
                identity -> Ash.Resource.Info.identity(relationship.destination, identity).keys
              end
              |> Enum.reject(&(&1 == relationship.destination_attribute))

            child_attributes = Ash.Resource.Info.attributes(relationship.destination)
            child_ignored = PaperTrail.ignore_attributes(relationship.destination)

            sort =
              relationship.destination
              |> Ash.Query.sort(relationship.sort || [])
              |> Ash.Query.default_sort(relationship.default_sort || [])
              |> Map.fetch!(:sort)

            [
              %{
                name: relationship.name,
                resource: relationship.destination,
                relationship: relationship,
                argument: argument,
                manage: manage,
                identity_fields: identity_fields,
                create_action: create_action,
                update_action: update_action,
                sort: sort,
                attributes: child_attributes,
                fields:
                  Enum.filter(child_attributes, fn attribute ->
                    attribute.writable? and not attribute.primary_key? and
                      attribute.name != relationship.destination_attribute and
                      (attribute.name not in child_ignored or attribute.sensitive?)
                  end)
              }
            ]
          else
            []
          end

        _ ->
          []
      end)
      |> Enum.uniq_by(& &1.name)

    %{
      resource: resource,
      action: action,
      attributes: attributes,
      fields: fields,
      ignored: ignored,
      relationships: relationships
    }
  end

  defp ordered_relationship_snapshots(snapshots, relationship) do
    entries = Enum.sort_by(snapshots, &elem(&1, 0))

    if relationship.sort == [] do
      entries
    else
      entries
      |> Enum.map(fn {key, values} ->
        child =
          Enum.reduce(relationship.attributes, struct(relationship.resource), fn attribute,
                                                                                 child ->
            case Map.fetch(values, to_string(attribute.name)) do
              {:ok, value} when not attribute.sensitive? ->
                {:ok, value} =
                  Ash.Type.cast_from_embedded(attribute.type, value, attribute.constraints)

                Map.put(child, attribute.name, value)

              _ ->
                child
            end
          end)

        Ash.Resource.set_metadata(child, %{audit_record_key: key})
      end)
      |> Ash.Sort.runtime_sort(relationship.sort, rekey?: false)
      |> Enum.map(fn child ->
        key = Ash.Resource.get_metadata(child, :audit_record_key)
        {key, Map.fetch!(snapshots, key)}
      end)
    end
  end

  defp recorded_changes(record, definition, actor) do
    root_resource = definition.resource
    version_resource = PaperTrail.version_resource(root_resource)
    primary_key_pairs = AshPaperTrail.Resource.PrimaryKey.pairs(root_resource)

    filter =
      Map.new(primary_key_pairs, fn {source, version} ->
        {version, Map.fetch!(record, source)}
      end)

    with {:ok, root_versions} <-
           version_resource |> Ash.Query.filter(^filter) |> Ash.read(actor: actor) do
      sources = [
        %{
          resource: root_resource,
          relationship: nil,
          primary_key_pairs: primary_key_pairs,
          versions: root_versions
        }
      ]

      Enum.reduce_while(definition.relationships, {:ok, sources}, fn relationship,
                                                                     {:ok, sources} ->
        child_versions = PaperTrail.version_resource(relationship.resource)
        foreign_key = relationship.relationship.destination_attribute
        primary_key_pairs = AshPaperTrail.Resource.PrimaryKey.pairs(relationship.resource)
        copied_owner? = not is_nil(Ash.Resource.Info.attribute(child_versions, foreign_key))

        query =
          if copied_owner? do
            filter = %{
              foreign_key => Map.fetch!(record, relationship.relationship.source_attribute)
            }

            Ash.Query.filter(child_versions, ^filter)
          else
            Ash.Query.new(child_versions)
          end

        result =
          with {:ok, versions} <- Ash.read(query, actor: actor) do
            if copied_owner? and versions != [] do
              source_keys =
                versions
                |> Enum.map(fn version ->
                  Map.new(primary_key_pairs, fn {_source, field} ->
                    {field, Map.fetch!(version, field)}
                  end)
                end)
                |> Enum.uniq()

              filter = [or: source_keys]
              child_versions |> Ash.Query.filter(^filter) |> Ash.read(actor: actor)
            else
              {:ok, versions}
            end
          end

        case result do
          {:ok, versions} ->
            {:cont,
             {:ok,
              sources ++
                [
                  %{
                    resource: relationship.resource,
                    relationship: relationship,
                    primary_key_pairs: primary_key_pairs,
                    versions: versions
                  }
                ]}}

          error ->
            {:halt, error}
        end
      end)
      |> case do
        {:ok, sources} ->
          events =
            Enum.flat_map(sources, fn source ->
              operation_field = PaperTrail.operation_id_field(source.resource)

              {events, _records} =
                source.versions
                |> Enum.sort_by(&{DateTime.to_unix(&1.version_inserted_at, :microsecond), &1.id})
                |> Enum.map_reduce(%{}, fn version, records ->
                  primary_key =
                    Map.new(source.primary_key_pairs, fn {field, version_field} ->
                      {to_string(field), Map.fetch!(version, version_field)}
                    end)

                  previous_values = Map.get(records, primary_key, %{})

                  values =
                    previous_values
                    |> Map.merge(version_attributes(source.resource, version))
                    |> Map.merge(primary_key)

                  key =
                    if source.relationship do
                      identity =
                        Enum.map(source.relationship.identity_fields, fn field ->
                          attribute = Ash.Resource.Info.attribute(source.resource, field)

                          {:ok, value} =
                            Ash.Type.cast_from_embedded(
                              attribute.type,
                              Map.get(values, to_string(field)),
                              attribute.constraints
                            )

                          {:ok, value} =
                            Ash.Type.dump_to_embedded(
                              attribute.type,
                              value,
                              attribute.constraints
                            )

                          value
                        end)

                      case identity do
                        [value] ->
                          if String.Chars.impl_for(value),
                            do: to_string(value),
                            else: Jason.encode!(value)

                        values ->
                          Jason.encode!(values)
                      end
                    end

                  {related?, was_related?} =
                    if source.relationship do
                      relationship = source.relationship.relationship

                      attribute =
                        Ash.Resource.Info.attribute(
                          source.resource,
                          relationship.destination_attribute
                        )

                      {:ok, expected} =
                        Ash.Type.dump_to_embedded(
                          attribute.type,
                          Map.fetch!(record, relationship.source_attribute),
                          attribute.constraints
                        )

                      field = to_string(relationship.destination_attribute)

                      {Map.fetch(values, field) == {:ok, expected},
                       Map.fetch(previous_values, field) == {:ok, expected}}
                    else
                      {true, false}
                    end

                  event = %{
                    id: to_string(version.id),
                    operation_id:
                      (operation_field && Map.get(version, operation_field)) ||
                        to_string(version.id),
                    version: version,
                    values: values,
                    relationship: source.relationship && source.relationship.name,
                    key: key,
                    related?: related?,
                    was_related?: was_related?,
                    source_key: primary_key
                  }

                  {event, Map.put(records, primary_key, values)}
                end)

              if source.relationship do
                Enum.filter(events, &(&1.related? or &1.was_related?))
              else
                events
              end
            end)

          {:ok, events}

        error ->
          error
      end
    end
  end

  defp version_attributes(resource, version) do
    attributes = Ash.Resource.Info.attributes(resource)

    ignored =
      PaperTrail.ignore_attributes(resource) ++
        Enum.map(Enum.filter(attributes, & &1.sensitive?), & &1.name)

    changes =
      if PaperTrail.change_tracking_mode(resource) in [:snapshot, :changes_only] do
        Map.new(Map.get(version, :changes) || %{}, fn {key, value} -> {to_string(key), value} end)
      else
        %{}
      end

    copied =
      PaperTrail.attributes_as_attributes(resource)
      |> Enum.reject(&(&1 in ignored))
      |> Map.new(fn field ->
        attribute = Ash.Resource.Info.attribute(resource, field)

        {:ok, value} =
          Ash.Type.dump_to_embedded(
            attribute.type,
            Map.fetch!(version, field),
            attribute.constraints
          )

        {to_string(field), value}
      end)

    changes |> Map.merge(copied) |> Map.drop(Enum.map(ignored, &to_string/1))
  end

  defp capture_state(record, definition) do
    attributes =
      definition.attributes
      |> Enum.reject(&(&1.name in definition.ignored or &1.sensitive? or &1.primary_key?))
      |> Map.new(fn attribute ->
        {:ok, value} =
          Ash.Type.dump_to_embedded(
            attribute.type,
            Map.fetch!(record, attribute.name),
            attribute.constraints
          )

        {to_string(attribute.name), value}
      end)

    related =
      Map.new(definition.relationships, fn relationship ->
        children =
          record
          |> Map.fetch!(relationship.name)
          |> List.wrap()
          |> Map.new(fn child ->
            values =
              relationship.attributes
              |> Enum.reject(& &1.sensitive?)
              |> Map.new(fn attribute ->
                {:ok, value} =
                  Ash.Type.dump_to_embedded(
                    attribute.type,
                    Map.fetch!(child, attribute.name),
                    attribute.constraints
                  )

                {to_string(attribute.name), value}
              end)

            identity =
              Enum.map(relationship.identity_fields, fn field ->
                attribute = Ash.Resource.Info.attribute(relationship.resource, field)

                {:ok, value} =
                  Ash.Type.cast_from_embedded(
                    attribute.type,
                    Map.get(values, to_string(field)),
                    attribute.constraints
                  )

                {:ok, value} =
                  Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)

                value
              end)

            key =
              case identity do
                [value] ->
                  if String.Chars.impl_for(value),
                    do: to_string(value),
                    else: Jason.encode!(value)

                values ->
                  Jason.encode!(values)
              end

            {key, values}
          end)

        {relationship.name, children}
      end)

    %{attributes: attributes, related: related}
  end

  defp compare_versions(definition, before, after_state) do
    fields =
      Enum.map(definition.fields, fn attribute ->
        key = to_string(attribute.name)
        old = if before.attributes == %{}, do: :missing, else: Map.fetch(before.attributes, key)
        restorable? = definition.action && attribute.name in definition.action.accept

        {key, Phoenix.Naming.humanize(attribute.name), attribute, old,
         Map.fetch(after_state.attributes, key), restorable?, nil, nil}
      end)

    related_fields =
      Enum.flat_map(definition.relationships, fn relationship ->
        old_records = Map.get(before.related, relationship.name, %{})
        new_records = Map.get(after_state.related, relationship.name, %{})

        old_records
        |> Map.merge(new_records)
        |> ordered_relationship_snapshots(relationship)
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {{key, _values}, index} ->
          Enum.map(relationship.fields, fn attribute ->
            name = to_string(attribute.name)

            old =
              if Map.has_key?(old_records, key),
                do: Map.fetch(old_records[key], name),
                else: :missing

            new =
              if Map.has_key?(new_records, key),
                do: Map.fetch(new_records[key], name),
                else: :missing

            label =
              "#{Phoenix.Naming.humanize(relationship.argument.name)} / #{index} / #{Phoenix.Naming.humanize(attribute.name)}"

            {"#{relationship.name}.#{key}.#{name}", label, attribute, old, new, true,
             relationship.name, key}
          end)
        end)
      end)

    Enum.map(fields ++ related_fields, fn {key, label, attribute, old, new, restorable?,
                                           relationship, record_key} ->
      status =
        cond do
          attribute.sensitive? or old == :error or new == :error ->
            :unknown

          old == new ->
            :unchanged

          old == :missing and new in [{:ok, nil}, {:ok, ""}, {:ok, []}] ->
            :unchanged

          new == :missing and old in [{:ok, nil}, {:ok, ""}, {:ok, []}] ->
            :unchanged

          true ->
            case {old, new} do
              {{:ok, old}, {:ok, new}} ->
                {:ok, old} =
                  Ash.Type.cast_from_embedded(attribute.type, old, attribute.constraints)

                {:ok, new} =
                  Ash.Type.cast_from_embedded(attribute.type, new, attribute.constraints)

                if Ash.Type.equal?(attribute.type, old, new, attribute.constraints),
                  do: :unchanged,
                  else: :changed

              _ ->
                :changed
            end
        end

      [old_value, new_value] =
        Enum.map([old, new], fn
          _value when attribute.sensitive? ->
            "Change not recorded"

          :missing ->
            "Not present"

          :error ->
            "Not recorded"

          {:ok, nil} ->
            "Not set"

          {:ok, []} ->
            "None"

          {:ok, value} ->
            cond do
              is_list(value) ->
                Enum.map_join(value, ", ", fn item ->
                  if String.Chars.impl_for(item), do: to_string(item), else: Jason.encode!(item)
                end)

              String.Chars.impl_for(value) ->
                to_string(value)

              true ->
                Jason.encode!(value)
            end
        end)

      %{
        key: key,
        label: label,
        attribute: attribute.name,
        relationship: relationship,
        record_key: record_key,
        before: old_value,
        after: new_value,
        before_present?: old != :missing,
        after_present?: new != :missing,
        status: status,
        restorable?: !!restorable? and status != :unknown and new not in [:missing, :error]
      }
    end)
  end
end
