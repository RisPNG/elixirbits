const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

const iconSets = {
  hero: [
    ["heroicons/optimized/24/outline", "", 6],
    ["heroicons/optimized/24/solid", "-solid", 6],
    ["heroicons/optimized/20/solid", "-mini", 5],
    ["heroicons/optimized/16/solid", "-micro", 4]
  ],
  tabler: [
    ["tabler_icons/icons/outline", "", 6],
    ["tabler_icons/icons/filled", "-filled", 6]
  ],
  simple: [
    ["simple_icons/icons", "", 6]
  ]
}

module.exports = plugin(function({matchComponents, theme}) {
  for (const [prefix, variants] of Object.entries(iconSets)) {
    const values = {}

    for (const [directory, suffix, spacing] of variants) {
      const iconsDir = path.join(__dirname, "../../deps", directory)
      for (const file of fs.readdirSync(iconsDir)) {
        if (path.extname(file) !== ".svg") continue
        const name = path.basename(file, ".svg") + suffix
        values[name] = {name, fullPath: path.join(iconsDir, file), spacing}
      }
    }

    matchComponents({
      [prefix]: ({name, fullPath, spacing}) => {
        let content = fs.readFileSync(fullPath, "utf8")
        if (prefix === "tabler") {
          content = content
            .replace(/<!--[\s\S]*?-->/g, "")
            .replace(/\s+/g, " ")
            .replace(/stroke-width="2"/g, 'stroke-width="1.5"')
            .replace(/^\s*<svg[^>]*>/, tag => tag.replace(/\s(?:width|height)="[^"]*"/g, ""))
            .trim()
        } else {
          content = content.replace(/[\r\n]/g, "")
        }

        const mask = `--${prefix}-${name}`
        const size = theme(`spacing.${spacing}`)

        return {
          [mask]: `url("data:image/svg+xml;utf8,${encodeURIComponent(content)}")`,
          "-webkit-mask": `var(${mask})`,
          "mask": `var(${mask})`,
          "mask-repeat": "no-repeat",
          "background-color": "currentColor",
          "vertical-align": "middle",
          "display": "inline-block",
          "width": size,
          "height": size
        }
      }
    }, {values})
  }
})
