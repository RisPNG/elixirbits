defmodule ElixirbitsWeb.CoreComponentBoundaryTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.TagEngine.Parser

  @core_file "lib/elixirbits_web/components/core_components.ex"
  @control_tags ~w(form input select textarea)
  @local_renderers ~w(combo_box live_file_input)
  @native_renderers ~w(
    Phoenix.Component.form Phoenix.Component.live_file_input PetalComponents.ComboBox.combo_box
    Phoenix.HTML.Tag.form_tag PhoenixHTMLHelpers.Tag.form_tag
  ) ++
                      Enum.flat_map(~w(Phoenix.HTML.Form PhoenixHTMLHelpers.Form), fn module ->
                        Enum.map(
                          ~w(form_for text_input email_input password_input number_input telephone_input
                             url_input search_input hidden_input file_input checkbox radio_button
                             select multiple_select textarea date_input time_input datetime_local_input
                             date_select time_select datetime_select color_input range_input),
                          &"#{module}.#{&1}"
                        )
                      end)

  test "application forms and inputs use their owning core components" do
    violations =
      ["lib/**/*.ex", "lib/**/*.heex", "test/**/*.ex", "test/**/*.exs", "test/**/*.heex"]
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.reject(&(&1 == @core_file))
      |> Enum.sort()
      |> Enum.flat_map(fn path ->
        source = File.read!(path)

        if Path.extname(path) == ".heex" do
          template_violations(source, path, 1)
        else
          source
          |> Code.string_to_quoted!(file: path, token_metadata: true)
          |> elixir_violations(path)
        end
      end)

    assert violations == [],
           "Application forms and inputs must use CoreComponents:\n#{Enum.join(violations, "\n")}"
  end

  test "the boundary detects rendered controls while ignoring documentation and HTML assertions" do
    source = ~S'''
    defmodule Example do
      @moduledoc "<input /> and Phoenix.Component.form are examples."

      def render(assigns) do
        ~H"""
        <%!-- <input /> --%>
        <form><input /><select></select><textarea></textarea></form>
        <Phoenix.Component.form for={nil} />
        <PetalComponents.ComboBox.combo_box field={@field} />
        <.live_file_input upload={@upload} />
        <.form for={nil}><.input name="email" value="" /></.form>
        {Phoenix.Component.live_file_input(@upload)}
        """
      end

      def native_form(assigns), do: Phoenix.Component.form(assigns)
      def native_select(assigns), do: PetalComponents.ComboBox.combo_box(assigns)
      def assertion(html), do: html =~ "<input />"
    end
    '''

    violations =
      source
      |> Code.string_to_quoted!(file: "example.ex", token_metadata: true)
      |> elixir_violations("example.ex")

    assert length(violations) == 10
    assert Enum.all?(violations, &String.starts_with?(&1, "example.ex:"))
    assert Enum.any?(violations, &String.contains?(&1, "<textarea>"))
    assert Enum.any?(violations, &String.contains?(&1, "Phoenix.Component.live_file_input"))
  end

  test "native EEx opening blocks and branch expressions cannot bypass the boundary" do
    source = ~S'''
    <%= PhoenixHTMLHelpers.Form.form_for @form, "/profile", fn form -> %>
      <.input field={form[:email]} type="email" />
    <% end %>
    <%= cond do %>
      <% PhoenixHTMLHelpers.Form.email_input(@form, :email) -> %>
        <.input name="email" type="email" value="" />
      <% true -> %>
        <%= Phoenix.HTML.Form.text_input(@form, :email) %>
    <% end %>
    '''

    violations = template_violations(source, "opening-block.html.heex", 10)

    assert length(violations) == 3
    assert Enum.any?(violations, &String.contains?(&1, "PhoenixHTMLHelpers.Form.form_for"))
    assert Enum.any?(violations, &String.contains?(&1, "PhoenixHTMLHelpers.Form.email_input"))
    assert Enum.any?(violations, &String.contains?(&1, "Phoenix.HTML.Form.text_input"))
  end

  defp elixir_violations(ast, path) do
    {_ast, violations} =
      Macro.prewalk(ast, [], fn
        {:sigil_H, meta, [{:<<>>, _string_meta, [source]}, _modifiers]} = node, violations ->
          line = meta[:line] + if(meta[:delimiter] in ["\"\"\"", "'''"], do: 1, else: 0)
          {node, violations ++ template_violations(source, path, line)}

        {{:., _dot_meta, [{:__aliases__, _alias_meta, module}, function]}, meta, _args} = node,
        violations ->
          renderer = Enum.join(module ++ [function], ".") |> String.trim_leading("Elixir.")

          if renderer in @native_renderers do
            {node, violations ++ ["#{path}:#{meta[:line]}: #{renderer}"]}
          else
            {node, violations}
          end

        node, violations ->
          {node, violations}
      end)

    violations
  end

  defp template_violations(source, path, line) do
    eex_violations =
      source
      |> EEx.compile_string(file: path, line: line, parser_options: [token_metadata: true])
      |> elixir_violations(path)

    markup_violations =
      source
      |> Parser.tokenize(file: path, line: line, tag_handler: Phoenix.LiveView.HTMLEngine)
      |> Enum.flat_map(fn
        {:tag, name, _attributes, meta} when name in @control_tags ->
          ["#{path}:#{meta.line}: <#{name}>"]

        {:local_component, name, _attributes, meta} when name in @local_renderers ->
          ["#{path}:#{meta.line}: <.#{name}>"]

        {:remote_component, name, _attributes, meta} when name in @native_renderers ->
          ["#{path}:#{meta.line}: <#{name}>"]

        {:body_expr, expression, meta} ->
          expression
          |> Code.string_to_quoted!(file: path, line: meta.line)
          |> elixir_violations(path)

        _token ->
          []
      end)

    eex_violations ++ markup_violations
  end
end
