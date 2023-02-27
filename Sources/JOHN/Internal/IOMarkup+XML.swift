//
//  IOMarkup+XML.swift
//  
//
//  Created by Alessio Giordano on 25/02/23.
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

extension IOMarkup {
    init?(xml: Data?) async {
        guard let xml else { return nil }
        let delegate = XML()
        do {
            /// Apple's XMLParser predates Swift Concurrency, so it is necessary to wrap it
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
                do {
                    let parser = XMLParser(data: xml)
                    parser.delegate = delegate
                    parser.parse()
                    if let error = parser.parserError {
                        throw error
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
                continuation.resume()
            }
        } catch { return nil }
        guard let root = delegate.root else { return nil }
        self.init(recursiveConversionOfElement: root) /// Root text nodes are not allowed
    }
    private init?(recursiveConversionOfElement node: XML.Node) {
        if case .element(let tagName, let attributes) = node.value {
            self.text = tagName
            self.wrappedAttributes = IOPayload(dictionary: attributes)
            self.wrappedChildren = IOPayload(array: node.children.compactMap {
                switch $0.value {
                case .element(_, _):    return IOMarkup.init(recursiveConversionOfElement: $0)
                case .text(let string): return IOPayload(text: string)
                }
            })
        } else { return nil }
    }
    
    /// Class used to parse the XML Document Tree
    class XML: NSObject, XMLParserDelegate {
        // MARK: Document tree
        var pending: Node? = nil {
            didSet {
                if root == nil {
                    root = pending
                }
            }
        }
        var root: Node? = nil
        class Node {
            private(set) var value: Value
            enum Value { case text(String), element(tagName: String, attributes: [String: String]) }
            private(set) var open: Bool
            private(set) var parent: Node?
            private(set) var children: [Node]
            private var currentTextNode: Node?
            
            init(_ value: Value) {
                self.value = value
                self.open = true
                self.parent = nil
                self.children = []
            }
            func append(textNode: String) {
                if self.open {
                    if let currentTextNode {
                        if case .text(let previous) = currentTextNode.value {
                            currentTextNode.value = .text(previous + textNode)
                        } else {
                            currentTextNode.value = .text(textNode)
                        }
                    } else {
                        let newTextNode: Node = .init(.text(textNode))
                        self.children.append(newTextNode)
                        self.currentTextNode = newTextNode
                    }
                }
            }
            func append(elementNode: Node) {
                if self.open {
                    self.currentTextNode = nil
                    elementNode.parent = self
                    self.children.append(elementNode)
                }
            }
            func close() -> Node? {
                self.open = false
                self.currentTextNode = nil
                return parent
            }
        }
        
        // MARK: XMLParserDelegate
        /// Start of element
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            let element = Node(.element(tagName: elementName, attributes: attributeDict))
            pending?.append(elementNode: element)
            self.pending = element /// Equivalent of setting self.depth += 1 in the Apple demo
        }
        /// Contents of element
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            pending?.append(textNode: string)
        }
        /// End of element
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            pending = pending?.close() /// Equivalent of setting self.depth -= 1 in the Apple demo
        }
    }
}
