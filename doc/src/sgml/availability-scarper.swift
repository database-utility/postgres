#!/usr/bin/env swift -enable-bare-slash-regex

import Foundation

let pages = (try! FileManager.default.contentsOfDirectory(atPath: "html"))
  .filter { $0.hasSuffix(".html") }
  .filter { $0.hasPrefix("sql-") || $0.hasPrefix("app-") || $0.hasPrefix("spi-") || $0.hasPrefix("ecpg-sql-") || $0 == "oid2name.html" || $0 == "vacuumlo.html" }
  .map { $0.replacingOccurrences(of: ".html", with: "") }

var results = [String: [String: String]]()

for page in pages {
  var versions = [String]()
  let url = URL(string: "https://www.postgresql.org/docs/current/\(page).html")!
  let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
  let (data, _) = try await URLSession.shared.data(for: request)
  let string = String(decoding: data, as: UTF8.self)
  string.enumerateLines { line, _ in
    if let match = try! /<a href="\/docs\/(?<version>[\d\.]+)\//.firstMatch(in: line) {
      var version = String(match.version)
      if !version.contains(".") { version += ".0" }
      versions.append(version)
    }
  }

  if !versions.contains("15.0") {
    fatalError()
  }

  if let firstSupportingVersion = versions.last {
    print("\(page): PostgreSQL \(firstSupportingVersion)+")
    results[page] = ["availableFrom": firstSupportingVersion]
  }
}

try! JSONSerialization.data(withJSONObject: results, options: .prettyPrinted).write(to: URL(fileURLWithPath: "./availability.json"))

for page in pages {
  guard let availableFrom = results[page]?["availableFrom"] else { continue }
  let badge = #"<span class="badge platform">PostgreSQL "# + availableFrom + #"+</span>"#
  let path = "./html/" + page + ".html"
  var string = try! String(contentsOfFile: path)
  string = string.replacingOccurrences(
    of: #"</div><div class="refsynopsisdiv">"#,
    with: #"</div>"# + badge + #"<div class="refsynopsisdiv">"#
  )
  try! string.write(toFile: path, atomically: true, encoding: .utf8)
}
