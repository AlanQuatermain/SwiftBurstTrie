# SwiftBurstTrie

An implementation of a burst trie, with an efficient memory-mappable immutable binary representation for saving & loading. Similar to CFBurstTrie, but less messy (I hope).

### Getting SwiftBurstTrie

In your `Package.swift` file's `dependencies` section, you can pull in the current master branch by adding the following:

```swift
.package(url: "https://github.com/AlanQuatermain/SwiftBurstTrie.git", .branch("master"))
```