//
//  IOMarkup+XML.swift
//  
//
//  Created by Alessio Giordano on 25/02/23.
//

import HTMLParser
import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

extension IOMarkup {
    init?(xml: Data?, containingJSON: Bool = false) async {
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
        self.init(recursiveConversionOfElement: root, parsingTextAsJSON: containingJSON) /// Root text nodes are not allowed
    }
    init?(soap: Data?, containingJSON: Bool = false) async {
        guard let root = await Self.init(xml: soap, containingJSON: containingJSON) else { return nil }
        /// Looking for Envelope
        guard let envelopeTagName = root.text?.uppercased(),
              let envelope = (envelopeTagName.hasSuffix(":ENVELOPE") || envelopeTagName == "ENVELOPE")
                                ? root : nil
            else { return nil }
        /// Looking for Body
        guard let bodyIndex = envelope.indices?.first(where: {
            let tagName = envelope[$0]?.text?.uppercased()
            return tagName?.hasSuffix(":BODY") ?? false || tagName == "BODY"
        }), let body = envelope[bodyIndex] as? Self else { return nil }
        self.text = body.text
        self.wrappedAttributes = body.wrappedAttributes
        self.wrappedChildren = body.wrappedChildren
        self.caseInsensitive = false
    }
    init?(html: Data?, containingJSON: Bool = false) async {
        guard let html else { return nil }
        let delegate = XML()
        do {
            /// Since HTMLParser is a drop-in replacement for XMLParser, it predates Swift Concurrency and it is necessary to wrap it
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
                do {
                    let parser = HTMLParser(data: html)
                    parser.delegate = delegate
                    _ = parser.parse()
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
        self.init(recursiveConversionOfElement: root, caseInsensitive: true, parsingTextAsJSON: containingJSON) /// Root text nodes are not allowed
    }
    private init?(recursiveConversionOfElement node: XML.Node, caseInsensitive: Bool = false, parsingTextAsJSON: Bool = false) {
        if Task.isCancelled {
            return nil
        }
        if case .element(let tagName, let attributes) = node.value {
            self.text = tagName
            self.caseInsensitive = caseInsensitive
            self.wrappedAttributes = IOPayload(dictionary: attributes)
            self.wrappedChildren = IOPayload(array: node.children.compactMap {
                switch $0.value {
                case .element(_, _):
                    return IOMarkup.init(recursiveConversionOfElement: $0, parsingTextAsJSON: parsingTextAsJSON)
                case .text(let string):
                    if !string.isEmpty {
                        if parsingTextAsJSON {
                            return IOPayload(json: string) ?? IOPayload(text: string)
                        } else {
                            return IOPayload(text: string)
                        }
                    } else { return nil }
                }
            })
        } else { return nil }
    }
    
    /// Class used to parse the XML Document Tree
    class XML: NSObject, XMLParserDelegate, HTMLParserDelegate {
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
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {/// Check for task cancellation
            let element = Node(.element(tagName: elementName, attributes: attributeDict))
            pending?.append(elementNode: element)
            self.pending = element /// Equivalent of setting self.depth += 1 in the Apple demo
            if Task.isCancelled {
                parser.abortParsing()
            }
        }
        /// Contents of element
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            pending?.append(textNode: string)
            if Task.isCancelled {
                parser.abortParsing()
            }
        }
        /// End of element
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            pending = pending?.close() /// Equivalent of setting self.depth -= 1 in the Apple demo
            if Task.isCancelled {
                parser.abortParsing()
            }
        }
        
        // MARK: HTMLParserDelegate
        /// Start of element
        func parser(_ parser: HTMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            let element = Node(.element(tagName: elementName, attributes: attributeDict))
            pending?.append(elementNode: element)
            self.pending = element /// Equivalent of setting self.depth += 1 in the Apple demo
            if Task.isCancelled {
                parser.abortParsing()
            }
        }
        /// Contents of element
        func parser(_ parser: HTMLParser, foundCharacters string: String) {
            pending?.append(textNode: string)
            if Task.isCancelled {
                parser.abortParsing()
            }
        }
        /// End of element
        func parser(_ parser: HTMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            pending = pending?.close() /// Equivalent of setting self.depth -= 1 in the Apple demo
            if Task.isCancelled {
                parser.abortParsing()
            }
        }
    }
}
