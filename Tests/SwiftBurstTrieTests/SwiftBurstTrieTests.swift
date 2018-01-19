import XCTest
@testable import SwiftBurstTrie

extension Int : MemoryBurdenCalculatable
{
    public var memoryBurden: Int {
        return MemoryLayout<Int>.size
    }
}

class SwiftBurstTrieTests: XCTestCase {
    func testInsert() {
        var trie = BurstTrie<Int>()
        
        trie["Hello"] = 1
        XCTAssertEqual(trie.count, 1)
        XCTAssertEqual(trie["Hello"], 1)
    }
    
    lazy var testInput: String = try! String(contentsOfFile: "/Users/jdovey/Projects/LinkedIn/schashes-tests/scds-hashes_scds-hashes.properties", encoding: .utf8)

    func testBurstingInserts() {
        var trie = BurstTrie<String>()
        
        let content: [String : String] = [
            "tl/emails/marketplace_lead_email/partials/footer.js" : "f3uwfqoy7rvci7kb9j12on2ch",
            "tl/emails/marketplace_lead_email/partials/template_body.js" : "2ia1iy0pcjvmwlzdn3ul6kdgl",
            "tl/emails/marketplace_lead_email/partials/button.js" : "bdmxxcqp13sf5x7y7izgc77em",
            "tl/emails/marketplace_lead_email/partials/plain_text.js" : "910kb5wz7kgskphq384y5n05y",
            "tl/emails/marketplace_lead_email/partials/header.js" : "7fr1rhwafei0dswrvazh633hn",
            "tl/emails/marketplace_lead_email/main.js" : "1wte8yja0a3wf80bo6bj8gj0m",
            "tl/emails/first_guest_reminder_01/germany/base.js" : "2lspq8ocrb1w689k9mcdqerqd",
            "tl/emails/first_guest_reminder_01/germany/partials/html/treatment_F.js" : "f5fd4yqjuh87gkavnfh0rku7h",
            "tl/emails/first_guest_reminder_01/germany/partials/html/treatment_B1.js" : "brtiswcmspyaqey3pxn69xrj3",
            "tl/emails/first_guest_reminder_01/germany/partials/html/treatment_A1.js" : "5qlr523eurs6uwe1i49myyxdn"
        ]
        
        for (key, value) in content {
            trie[key] = value
        }
        
        XCTAssertEqual(trie.count, content.count)
        for (key, value) in content {
            XCTAssertEqual(trie[key], value)
        }
        
        print(trie.debugDescription)
    }
    
    func testHugeTrie() {
        var trie = BurstTrie<String>(maxContainerCost: 2048)
        
        print("Loading test data into trie...")
        let start = CFAbsoluteTimeGetCurrent()
        testInput.enumerateLines { line, stopNow in
            guard let range = line.range(of: "=") else {
                return
            }
            
            let key = String(line[..<range.lowerBound])
            let value = String(line[range.upperBound...])
            
            trie[key] = value
        }
        print("...done loading data into trie, took \(CFAbsoluteTimeGetCurrent() - start) seconds.")
        
        XCTAssertEqual(trie.count, 54_109)
        XCTAssertEqual(trie["scripts/apps/biz/components/BizNonBlockingIframe.js"], "bfgf5z2q0gtf54zswakl4gjxr")
        XCTAssertEqual(trie["js/apps/PublisherShareWizard.js"], "56e92rbdzaal8qh1nq8gicga3")
        
        print("Approximate memory burden: \(trie.memoryBurden)")
        
        XCTAssertNoThrow(try trie.debugDescription.write(toFile: "/Users/jdovey/Desktop/TrieContent.txt", atomically: true, encoding: .utf8))
    }

    static var allTests = [
        ("testInsert", testInsert),
        ("testBurstingInserts", testBurstingInserts),
        ("testHugeTrie", testHugeTrie)
    ]
}
