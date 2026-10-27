import Testing
import Foundation
@testable import Jarvis

struct RSSParserTests {
    let sample = """
    <?xml version="1.0"?>
    <rss version="2.0"><channel>
      <title>Example Feed</title>
      <item><title>First headline</title><link>https://x/1</link></item>
      <item><title>Second &amp; better headline</title></item>
      <item><title>Third headline</title></item>
    </channel></rss>
    """

    @Test func parsesItemTitles() {
        let titles = RSSParser.headlines(fromXML: Data(sample.utf8), limit: 10)
        #expect(titles == ["First headline", "Second & better headline", "Third headline"])
    }

    @Test func channelTitleIsNotAHeadline() {
        let titles = RSSParser.headlines(fromXML: Data(sample.utf8), limit: 10)
        #expect(!titles.contains("Example Feed"))
    }

    @Test func respectsLimit() {
        let titles = RSSParser.headlines(fromXML: Data(sample.utf8), limit: 2)
        #expect(titles.count == 2)
    }

    @Test func malformedXMLYieldsEmpty() {
        let titles = RSSParser.headlines(fromXML: Data("not xml".utf8), limit: 5)
        #expect(titles.isEmpty)
    }
}
