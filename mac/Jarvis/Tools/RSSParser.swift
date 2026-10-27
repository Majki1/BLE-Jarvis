import Foundation

// Minimal RSS reader: item titles only, which is all a spoken briefing needs.
enum RSSParser {
    static func headlines(fromXML data: Data, limit: Int) -> [String] {
        let delegate = ItemTitleCollector()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return Array(delegate.titles.prefix(limit))
    }
}

private final class ItemTitleCollector: NSObject, XMLParserDelegate {
    var titles: [String] = []
    private var insideItem = false
    private var currentTitle: String?

    func parser(_ parser: XMLParser, didStartElement name: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if name == "item" || name == "entry" { insideItem = true }
        if insideItem && name == "title" { currentTitle = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentTitle? += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String,
                namespaceURI: String?, qualifiedName: String?) {
        if name == "title", insideItem, let title = currentTitle {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { titles.append(trimmed) }
            currentTitle = nil
        }
        if name == "item" || name == "entry" { insideItem = false }
    }
}
