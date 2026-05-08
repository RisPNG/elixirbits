const plugin = require("tailwindcss/plugin")

module.exports = plugin(function ({ matchUtilities, theme }) {
  matchUtilities(
    {
      subgap: (value) => ({
        "--subgap": value,
        columnGap: "0",
        "> *": {
          minWidth: "0",
        },
        "> :not(:last-child)": {
          marginInlineEnd: "var(--subgap)",
        },
      }),
    },
    {
      values: theme("spacing"),
      type: ["length", "percentage"],
    }
  )
})
