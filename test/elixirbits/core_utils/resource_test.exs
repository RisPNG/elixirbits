defmodule Elixirbits.CoreUtils.ResourceTest do
  use ExUnit.Case, async: true

  alias Elixirbits.CoreUtils.Resource
  alias Elixirbits.CoreUtils.ResourceTest.FormChild
  alias Elixirbits.CoreUtils.ResourceTest.FormDomain
  alias Elixirbits.CoreUtils.ResourceTest.FormParent
  alias Elixirbits.CoreUtils.ResourceTest.FormRow
  alias Elixirbits.CoreUtils.ResourceTest.SequenceRow

  test "next_sequence handles values, records, and custom field names" do
    assert Resource.next_sequence([], start: 10, increment: 10) == 10
    assert Resource.next_sequence([%{sequence: 10}, %{"sequence" => "20"}], increment: 10) == 30
    assert Resource.next_sequence(["1", 3, nil]) == 4
    assert Resource.next_sequence([%{position: 2}], field: :position) == 3

    assert Resource.next_sequence([],
             start: 3,
             prefix: "INV",
             suffix: "MY",
             padding: 4,
             separator: "/"
           ) == "INV/0003/MY"
  end

  test "next_sequence reads AshPhoenix and Phoenix nested forms after input changes" do
    row = AshPhoenix.Form.for_create(SequenceRow, :create, params: %{"sequence" => "20"})
    changed = AshPhoenix.Form.validate(row, %{"sequence" => "30"})
    form = %{row | forms: %{rows: [row, changed]}}
    html_form = Phoenix.Component.to_form(form)

    assert Resource.next_sequence([row, Phoenix.Component.to_form(changed)], increment: 10) == 40
    assert Resource.next_sequence(form, :rows, increment: 10) == 40
    assert Resource.next_sequence(html_form, :rows, increment: 10) == 40
    assert Resource.next_sequence(html_form, :missing, start: 10) == 10
  end

  test "resource metadata chooses the field's datetime precision" do
    input = "2026-07-13T02:00:00.123456Z"
    assert Resource.convert_value_to_field(SequenceRow, :at, input) == ~U[2026-07-13 02:00:00Z]

    assert Resource.convert_value_to_field(SequenceRow, :precise_at, input) ==
             ~U[2026-07-13 02:00:00.123456Z]

    assert Resource.convert_value_to_field(SequenceRow, :local_at, input) ==
             ~N[2026-07-13 02:00:00]
  end

  test "native datetime and NewType storage metadata retain precision and public invalid fallbacks" do
    for field <- [:native_at, :wrapped_at] do
      assert Resource.convert_value_to_field(
               FormRow,
               field,
               "2026-07-13T10:00:00.123456",
               "Asia/Kuala_Lumpur"
             ) == ~U[2026-07-13 02:00:00.123456Z]

      assert Resource.convert_value_to_field(FormRow, field, "invalid") == nil

      assert Resource.convert_value_to_field(
               FormRow,
               field,
               "2026-11-01T01:30",
               "America/New_York"
             ) == nil
    end
  end

  test "native forms submit UTC datetime fields and typed arguments while date and time stay unchanged" do
    params = %{
      "at" => "2026-07-13T10:00:00.123456",
      "precise_at" => "2026-07-13T10:00:00.123456",
      "native_at" => "2026-07-13T10:00:00.123456",
      "wrapped_at" => "2026-07-13T10:00:00.123456",
      "remind_at" => "2026-07-13T11:00:00.654321",
      "slots" => ["2026-07-13T10:00:00.123456", "2026-07-13T11:00:00.654321"],
      "due_date" => "2026-07-13",
      "opens_at" => "10:00:00",
      "local_at" => "2026-07-13T10:00:00"
    }

    form =
      FormRow
      |> AshPhoenix.Form.for_create(:create,
        domain: FormDomain,
        context: %{shared: %{user_timezone: "Asia/Kuala_Lumpur"}},
        transform_params: &Resource.convert_form_datetimes/3,
        post_process_errors: &Resource.local_datetime_errors/3
      )
      |> AshPhoenix.Form.validate(params)

    assert form.valid?
    assert form.raw_params == params
    assert form.params["due_date"] == params["due_date"]
    assert form.params["opens_at"] == params["opens_at"]
    assert form.params["local_at"] == params["local_at"]

    assert Resource.convert_form_datetimes(form, form.params, :validate) == form.params
    assert {:ok, record} = AshPhoenix.Form.submit(form, params: nil)
    stored = Ash.get!(FormRow, record.id, domain: FormDomain)

    assert stored.at == ~U[2026-07-13 02:00:00Z]
    assert stored.precise_at == ~U[2026-07-13 02:00:00.123456Z]
    assert stored.native_at == stored.precise_at
    assert stored.wrapped_at == stored.precise_at
    assert stored.reminder_at == ~U[2026-07-13 03:00:00.654321Z]
    assert stored.slots == [stored.precise_at, stored.reminder_at]
    assert stored.due_date == ~D[2026-07-13]
    assert stored.opens_at == ~T[10:00:00]
    assert stored.local_at == ~N[2026-07-13 10:00:00]
  end

  test "optional local datetimes reject DST errors without losing raw input or clearing the field" do
    for {input, reason, message} <- [
          {"2026-03-08T02:30", :nonexistent_datetime, "does not exist in %{timezone}"},
          {"2026-11-01T01:30", :ambiguous_datetime,
           "occurs twice in %{timezone}, so include a UTC offset to choose the intended time"},
          {"2026-07-13T10:00:00+25:00", :invalid_datetime, "must be a valid date and time"}
        ] do
      form =
        FormRow
        |> AshPhoenix.Form.for_create(:create,
          domain: FormDomain,
          context: %{shared: %{user_timezone: "America/New_York"}},
          transform_params: &Resource.convert_form_datetimes/3,
          post_process_errors: &Resource.local_datetime_errors/3
        )
        |> AshPhoenix.Form.validate(%{"native_at" => input}, errors: true)

      refute form.valid?
      assert form.raw_params["native_at"] == input
      assert form.params["native_at"] == {:error, reason}
      assert AshPhoenix.Form.value(form, :native_at) == {:error, reason}
      assert Resource.convert_form_datetimes(form, form.params, :validate) == form.params

      html_form = Phoenix.Component.to_form(form)
      assert html_form[:native_at].value == {:error, reason}
      assert {^message, vars} = List.first(html_form[:native_at].errors)

      if reason != :invalid_datetime, do: assert(vars[:timezone] == "America/New_York")

      assert {:error, submitted} = AshPhoenix.Form.submit(form, params: nil)
      refute submitted.valid?
      assert submitted.raw_params["native_at"] == input

      assert {^message, _vars} =
               List.first(Phoenix.Component.to_form(submitted)[:native_at].errors)

      assert Ash.read!(FormRow, domain: FormDomain) == []
    end
  end

  test "explicit offsets choose repeated-clock instants and empty optional datetimes remain valid" do
    form =
      AshPhoenix.Form.for_create(FormRow, :create,
        domain: FormDomain,
        context: %{shared: %{user_timezone: "America/New_York"}},
        transform_params: &Resource.convert_form_datetimes/3,
        post_process_errors: &Resource.local_datetime_errors/3
      )

    for {input, expected} <- [
          {"2026-11-01T01:30:00.123456-04:00", ~U[2026-11-01 05:30:00.123456Z]},
          {"2026-11-01T01:30:00.123456-05:00", ~U[2026-11-01 06:30:00.123456Z]},
          {"", nil}
        ] do
      validated = AshPhoenix.Form.validate(form, %{"native_at" => input})
      assert validated.valid?
      assert {:ok, record} = AshPhoenix.Form.submit(validated, params: nil)
      assert record.native_at == expected
    end
  end

  test "native nested callbacks inherit timezone and validate child UTC values before submission" do
    forms =
      FormParent
      |> AshPhoenix.Form.Auto.auto(:create)
      |> Keyword.update!(:children, fn opts ->
        Keyword.put_new(opts, :transform_params, &Resource.convert_form_datetimes/3)
      end)

    form =
      FormParent
      |> AshPhoenix.Form.for_create(:create,
        domain: FormDomain,
        forms: forms,
        context: %{shared: %{user_timezone: "Asia/Kuala_Lumpur"}},
        transform_params: &Resource.convert_form_datetimes/3,
        post_process_errors: &Resource.local_datetime_errors/3
      )
      |> AshPhoenix.Form.add_form([:children], type: :create)
      |> AshPhoenix.Form.validate(%{
        "children" => %{"0" => %{"at" => "2026-07-13T10:00:00.123456"}}
      })

    child_form = AshPhoenix.Form.get_form(form, [:children, 0])
    assert form.valid?
    assert get_in(child_form.opts, [:context, :shared, :user_timezone]) == "Asia/Kuala_Lumpur"
    assert AshPhoenix.Form.value(child_form, :at) == ~U[2026-07-13 02:00:00.123456Z]
    assert Phoenix.Component.to_form(child_form)[:at].value == ~U[2026-07-13 02:00:00.123456Z]
    assert child_form.raw_params["at"] == "2026-07-13T10:00:00.123456"

    assert {:ok, parent} = AshPhoenix.Form.submit(form, params: nil)
    [child] = Ash.read!(FormChild, domain: FormDomain)
    assert child.form_parent_id == parent.id
    assert child.at == ~U[2026-07-13 02:00:00.123456Z]
  end

  test "nested DST errors stay on the child and prevent the native parent action" do
    forms =
      FormParent
      |> AshPhoenix.Form.Auto.auto(:create)
      |> Keyword.update!(:children, fn opts ->
        Keyword.put_new(opts, :transform_params, &Resource.convert_form_datetimes/3)
      end)

    form =
      FormParent
      |> AshPhoenix.Form.for_create(:create,
        domain: FormDomain,
        forms: forms,
        context: %{shared: %{user_timezone: "America/New_York"}},
        transform_params: &Resource.convert_form_datetimes/3,
        post_process_errors: &Resource.local_datetime_errors/3
      )
      |> AshPhoenix.Form.add_form([:children], type: :create)
      |> AshPhoenix.Form.validate(
        %{"children" => %{"0" => %{"at" => "2026-03-08T02:30"}}},
        errors: true
      )

    child_form = AshPhoenix.Form.get_form(form, [:children, 0])
    refute form.valid?
    refute child_form.valid?
    assert child_form.raw_params["at"] == "2026-03-08T02:30"
    assert AshPhoenix.Form.value(child_form, :at) == {:error, :nonexistent_datetime}

    assert {"does not exist in %{timezone}", [timezone: "America/New_York"]} in Phoenix.Component.to_form(
             child_form
           )[:at].errors

    assert {:error, submitted} = AshPhoenix.Form.submit(form, params: nil)
    refute submitted.valid?
    assert Ash.read!(FormParent, domain: FormDomain) == []
    assert Ash.read!(FormChild, domain: FormDomain) == []
  end

  test "new nested params submitted directly still convert local instants before the native child action" do
    forms =
      FormParent
      |> AshPhoenix.Form.Auto.auto(:create)
      |> Keyword.update!(:children, fn opts ->
        Keyword.put_new(opts, :transform_params, &Resource.convert_form_datetimes/3)
      end)

    form =
      AshPhoenix.Form.for_create(FormParent, :create,
        domain: FormDomain,
        forms: forms,
        context: %{shared: %{user_timezone: "Asia/Kuala_Lumpur"}},
        transform_params: &Resource.convert_form_datetimes/3,
        post_process_errors: &Resource.local_datetime_errors/3
      )

    assert {:ok, parent} =
             AshPhoenix.Form.submit(form,
               params: %{"children" => %{"0" => %{"at" => "2026-07-13T10:00:00.123456"}}}
             )

    [child] = Ash.read!(FormChild, domain: FormDomain)
    assert child.form_parent_id == parent.id
    assert child.at == ~U[2026-07-13 02:00:00.123456Z]
  end

  test "new nested DST params cannot bypass the native child datetime cast" do
    forms =
      FormParent
      |> AshPhoenix.Form.Auto.auto(:create)
      |> Keyword.update!(:children, fn opts ->
        Keyword.put_new(opts, :transform_params, &Resource.convert_form_datetimes/3)
      end)

    form =
      AshPhoenix.Form.for_create(FormParent, :create,
        domain: FormDomain,
        forms: forms,
        context: %{shared: %{user_timezone: "America/New_York"}},
        transform_params: &Resource.convert_form_datetimes/3,
        post_process_errors: &Resource.local_datetime_errors/3
      )

    assert {:error, submitted} =
             AshPhoenix.Form.submit(form,
               params: %{"children" => %{"0" => %{"at" => "2026-03-08T02:30"}}}
             )

    refute submitted.valid?
    assert Ash.read!(FormChild, domain: FormDomain) == []
  end
end
