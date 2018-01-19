//
//  Trie.swift
//  SwiftBurstTrie
//
//  Created by Jim Dovey on 1/18/18.
//  Copyright (c) 2018, Jim Dovey
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//  * Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation

extension String
{
    var decomposed: (Character, String)? {
        return isEmpty ? nil : (first!, String(dropFirst()))
    }
}

private let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~%!$&'()*+,;=:@/"

private let _fastCharSlot: [Character : Int] = {
    var result = [Character : Int]()
    for (idx, char) in allowedCharacters.enumerated() {
        result[char] = idx + 1
    }
    return result
}()
private let containerArraySize = _fastCharSlot.count + 1

public protocol MemoryBurdenCalculatable
{
    var memoryBurden: Int { get }
}

extension String : MemoryBurdenCalculatable
{
    public var memoryBurden: Int {
        return count
    }
}

public struct BurstTrie<T : MemoryBurdenCalculatable>
{
    public static var defaultMaxContainerCost: Int { return 256 }
    private let maxContainerCost: Int
    
    private var root: Node
    
    private class Node
    {
        var contents: NodeContents
        let maxContainerCost: Int
        
        init(_ contents: NodeContents, maxContainerCost: Int = BurstTrie.defaultMaxContainerCost) {
            self.contents = contents
            self.maxContainerCost = maxContainerCost
        }
        
        var count: Int {
            switch contents {
            case .subtrie(let content):
                return content.reduce(0) { $0 + ($1?.count ?? 0) }
            case .container(let content):
                return content.count
            case .value:
                return 1
            }
        }
        
        var depth: Int {
            switch contents {
            case .subtrie(let content):
                return content.reduce(0) { max($0, $1?.depth ?? 0) } + 1
            case .container:
                return 1
            case .value:
                return 0
            }
        }
        
        var memoryBurden: Int {
            switch contents {
            case .subtrie(let content):
                return content.reduce(content.count) { $0 + ($1?.memoryBurden ?? 0) }
            case .container(let content):
                return content.reduce(0) { $0 + $1.key.count + $1.value.memoryBurden }
            case .value(let v):
                return v.memoryBurden
            }
        }
        
        func buildDebugDescription(withIndent indent: Int = 0, parent: String? = nil) -> String {
            let indentStr = String(repeating: "  ", count: indent)
            var output = String()
            
            switch contents {
            case .subtrie(let content):
                let thisCount = content.reduce(0) { $0 + ($1 == nil ? 0 : 1) }
                output += indentStr + "Subtrie '\(parent ?? "<root>")' with \(thisCount) children:\n"
                for (idx, node) in content.enumerated() where node != nil {
                    let parent = idx == 0 ? nil : String(allowedCharacters[allowedCharacters.index(allowedCharacters.startIndex, offsetBy: idx-1)])
                    output += node!.buildDebugDescription(withIndent: indent + 1, parent: parent)
                }
            case .container(let content):
                output += indentStr + "Container '\(parent ?? "<root>")' with \(content.count) children:\n"
                for (key, value) in content {
                    output += indentStr + "  \(key) = \(value)\n"
                }
            case .value(let v):
                output += indentStr + "Value for '\(parent ?? "<root>")': \(v)\n"
            }
            
            return output
        }
        
        private func _insertEmpty(value: T) {
            switch contents {
            case .subtrie(var content):
                // insert a value node at location zero
                content[0] = Node(.value(value), maxContainerCost: maxContainerCost)
                contents = .subtrie(content)
            case .container(var content):
                // insert a value paired to an empty string
                content[""] = value
                contents = .container(content)
            case .value:
                // replace the existing value node
                contents = .value(value)
            }
        }
        
        private func _removeEmpty() {
            switch contents {
            case .subtrie(var content):
                content[0] = nil
            case .container(var content):
                content.removeValue(forKey: "")
            case .value:
                // argh!
                break
            }
        }
        
        func insert(value: T, forKey key: String) {
            guard let (head, tail) = key.decomposed else {
                _insertEmpty(value: value)
                return
            }
            guard let slot = _fastCharSlot[head] else {
                // invalid key character
                return
            }
            
            switch contents {
            case .subtrie(var content):
                if let subnode = content[slot] {
                    subnode.insert(value: value, forKey: tail)
                }
                else {
                    let subnode = Node(.container([:]), maxContainerCost: maxContainerCost)
                    subnode.insert(value: value, forKey: tail)
                    content[slot] = subnode
                }
                contents = .subtrie(content)
            case .container(var content):
                content[key] = value
                contents = .container(content)
                if contents.cost > maxContainerCost {
                    contents = contents.burstContainer(maxLength: maxContainerCost)
                }
            case .value:
                contents = contents.burstValue(maxLength: maxContainerCost)
                insert(value: value, forKey: key)   // recurse to insert into the new content
            }
        }
        
        func removeValue(forKey key: String) {
            if case .value = contents {
                preconditionFailure("Cannot invoke \(#function) on a .value node!")
            }
            
            guard let (head, tail) = key.decomposed else {
                _removeEmpty()
                return
            }
            
            guard let slot = _fastCharSlot[head] else {
                return  // invalid character
            }
            
            switch contents {
            case .subtrie(var content):
                guard let subnode = content[slot] else {
                    return  // key not found
                }
                if tail.isEmpty {
                    // just remove this node
                    content[slot] = nil
                }
                else {
                    // recurse into the subnode
                    subnode.removeValue(forKey: tail)
                }
            case .container(var content):
                content.removeValue(forKey: key)
            case .value:
                // should never get here...
                break
            }
        }
        
        private func _getEmptyValue() -> T? {
            switch contents {
            case .subtrie(let content):
                guard let subnode = content[0] else {
                    // no value recorded
                    return nil
                }
                guard case let .value(v) = subnode.contents else {
                    // item at index 0 is *always* a .value
                    preconditionFailure("Content at subtrie[0] MUST ALWAYS be NodeContents.value.")
                }
                return v
            case .container(let content):
                return content[""]
            case .value(let v):
                return v
            }
        }
        
        func retrieve(_ key: String) -> T? {
            guard let (head, tail) = key.decomposed else {
                // look for an empty-string value
                return _getEmptyValue()
            }
            
            guard let slot = _fastCharSlot[head] else {
                // invalid character in lookup string
                return nil
            }
            
            switch contents {
            case .subtrie(let content):
                return content[slot]?.retrieve(tail)
            case .container(let content):
                return content[key]
            case .value:
                return nil      // string reaches into unknown territory...
            }
        }
    }
    
    private enum NodeContents
    {
        case subtrie(ContiguousArray<Node?>)
        case container([String : T])
        case value(T)
        
        static func newSubtrieArray() -> ContiguousArray<Node?> {
            return ContiguousArray(repeating: nil, count: containerArraySize)
        }
        
        func burstValue(maxLength: Int) -> NodeContents {
            guard case .value = self else {
                preconditionFailure(#function + " should only be called on a .value() NodeContents")
            }
            
            var table = NodeContents.newSubtrieArray()
            table[0] = Node(self, maxContainerCost: maxLength)
            
            return .subtrie(table)
        }
        
        func burstContainer(maxLength: Int) -> NodeContents {
            guard case let .container(contents) = self else {
                preconditionFailure(#function + " should only be called on a .container() NodeContents")
            }
            
            var table = NodeContents.newSubtrieArray()
            for (str, value) in contents {
                guard let (head, tail) = str.decomposed else {
                    table[0] = Node(.value(value), maxContainerCost: maxLength)
                    continue
                }
                
                let slot = _fastCharSlot[head]!
                if tail.isEmpty {
                    // only the single head character left-- add a value node below the lookup
                    table[slot] = Node(.value(value), maxContainerCost: maxLength)
                }
                else {
                    // record a substring -> value mapping subnode
                    if let subnode = table[slot] {
                        subnode.insert(value: value, forKey: tail)  // this may cause a further burst
                    }
                    else {
                        table[slot] = Node(.container([tail : value]), maxContainerCost: maxLength)
                    }
                }
            }
            
            return .subtrie(table)
        }
        
        var cost: Int {
            switch self {
            case .subtrie, .value:
                return 1        // constant cost; these don't burst
            case .container(let content):
                // total number of characters stored
                return content.reduce(0) { $0 + $1.key.count }
            }
        }
    }
    
    public init() {
        self.init(maxContainerCost: BurstTrie.defaultMaxContainerCost)
    }
    
    public init(maxContainerCost: Int) {
        self.maxContainerCost = maxContainerCost
        self.root = Node(.container([:]), maxContainerCost: maxContainerCost)
    }
    
    public var count: Int {
        return root.count
    }
    
    public var depth: Int {
        return root.depth
    }
    
    public var memoryBurden: Int {
        return root.memoryBurden
    }
    
    public subscript(_ key: String) -> T? {
        get {
            return root.retrieve(key)
        }
        set {
            if let value = newValue {
                root.insert(value: value, forKey: key)
            }
            else {
                root.removeValue(forKey: key)
            }
        }
    }
}

extension BurstTrie : CustomStringConvertible, CustomDebugStringConvertible
{
    public var description: String {
        return "BurstTrie of depth \(depth) containing \(count) items"
    }
    
    public var debugDescription: String {
        return description + "\n" + root.buildDebugDescription()
    }
}
