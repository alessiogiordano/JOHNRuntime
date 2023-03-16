//
//  IOPagination.swift
//  
//
//  Created by Alessio Giordano on 21/02/23.
//

import Foundation

struct IOPagination: IOProtocol {
    private(set) var wrappedPages: [any IOProtocol]
    var wrappedValue: Any {
        wrappedPages.map { $0.wrappedValue }
    }
    mutating func prependPage(_ page: any IOProtocol) {
        wrappedPages.insert(page, at: 0)
    }
    mutating func appendPage(_ page: any IOProtocol) {
        wrappedPages.append(page)
    }
    // MARK: Pagination policy
    let defaultAccessPolicy: Merger.Policy
    let accessPolicy: [String: Merger.Policy]
    
    // MARK: Iterator
    var iterator: Iterator? = nil
    struct Iterator {
        let variable: String
        let chunk: Int
        var offset: Int
        var total: Int { offset + chunk }
        mutating func advance() -> Int {
            self.offset += self.chunk
            return self.offset
        }
        func toPayload() -> IOPayload {
            return .init(dictionary: [
                "chunk":    self.chunk,
                "offset":   self.offset,
                "total":    self.total
            ])
        }
    }
    
    // MARK: Text node getter
    var text: String? {
        /// Reuse code for both .keep and .replace policies
        let firstInstanceOfTextNode: ([any IOProtocol]) -> String? = { collection in
            var text: String? = nil
            for value in collection {
                text = value.text
                if text != nil {
                    break
                }
            }
            return text
        }
        /// Keep returns the first non nil text node starting from the beginning of the paginated payload
        /// First always returns the value of the first page
        /// Replace returns the first non nil text node starting from the end of the paginated payload
        /// Last always returns the value of the last page
        /// Append doesn't make sense without a concatenation policy so it is skipped
        switch defaultAccessPolicy {
            case .first:    return wrappedPages.first?.text
            case .keep:     return firstInstanceOfTextNode(wrappedPages)
            case .append:   return nil
            case .replace:  return firstInstanceOfTextNode(wrappedPages.reversed())
            case .last:     return wrappedPages.last?.text
            case .none:     return nil
        }
    }
    
    // MARK: Array subscript
    var indices: Range<Int>? {
        var count = 0
        for page in wrappedPages {
            count += page.indices?.count ?? 1
        }
        if count > 0 {
            return 0..<count
        } else {
            return nil
        }
    }
    subscript(_ index: Int) -> (any IOProtocol)? {
        /// Reuse code for both .keep and .replace policies
        let firstInstanceOfArrayNode: ([any IOProtocol]) -> (any IOProtocol)? = { collection in
            var array: (any IOProtocol)? = nil
            for value in collection {
                if value.indices != nil {
                    array = value
                    break
                }
            }
            return array
        }
        /// Keep subscripts the first array found starting from the beginning of the paginated payload
        /// First always attempts to subscript the first page
        /// Replace subscripts the first array found starting from the end of the paginated payload
        /// Last always attempts to subscript the last page
        /// Append treats the whole paginated hierarchy as one flattened array, concatenating the indices
        switch defaultAccessPolicy {
            case .first:    return wrappedPages.first?[index]
            case .keep:     return firstInstanceOfArrayNode(wrappedPages)?[index]
            case .replace:  return firstInstanceOfArrayNode(wrappedPages.reversed())?[index]
            case .last:     return wrappedPages.last?[index]
            case .none:     return wrappedPages[index]
            case .append:
                var iterator: Int = 0
                for page in wrappedPages {
                    let pageIndices = page.indices
                    if let pageIndices {
                        /// Array
                        let relativeIndex = index - iterator
                        if relativeIndex < pageIndices.count {
                            return page[relativeIndex]
                        } else {
                            iterator += pageIndices.count
                        }
                    } else {
                        /// Dictionary or String
                        if iterator == index {
                            return page
                        } else {
                            iterator += 1
                        }
                    }
                }
                /// Out of bounds
                return nil
        }
        
        
    }
    
    // MARK: Dictionary lookup
    var keys: [String] {
        return wrappedPages.flatMap { $0.keys }
    }
    subscript(_ key: String) -> (any IOProtocol)? {
        /// Override behavior for accessing the iterator
        if let iterator, key == iterator.variable {
            return iterator.toPayload()
        }
        /// Reuse code for both .keep and .replace policies
        let firstInstanceOfDictionaryNode: ([any IOProtocol]) -> (any IOProtocol)? = { collection in
            var dictionary: (any IOProtocol)? = nil
            for value in collection {
                if value.keys.contains(key) {
                    dictionary = value
                    break
                }
            }
            return dictionary
        }
        /// Keep looks up the first dictionary found starting from the beginning of the paginated payload that contains the given key
        /// First always attempts to look up the first page
        /// Replace looks up the first dictionary found starting from the end of the paginated payload that contains the given key
        /// Last always attempts to look up the last page
        /// Append doesn't make sense with dictionary lookups
        switch accessPolicy[key] ?? defaultAccessPolicy {
            case .first:    return wrappedPages.first?[key]
            case .keep:     return firstInstanceOfDictionaryNode(wrappedPages)?[key]
            case .append:   return IOPayload(array: wrappedPages.compactMap {
                                return $0[key]
                            })
            case .replace:  return firstInstanceOfDictionaryNode(wrappedPages.reversed())?[key]
            case .last:     return wrappedPages.last?[key]
            case .none:     return nil
        }
    }
    
    // MARK: Initializers
    internal init(wrappedPages: [any IOProtocol], mergingPolicy: Merger?) {
        self.wrappedPages = wrappedPages
        self.defaultAccessPolicy = mergingPolicy?.default ?? .none
        self.accessPolicy = mergingPolicy?.override ?? [:]
    }
}
