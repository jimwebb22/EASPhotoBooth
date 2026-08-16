// KDTree.swift — EtchBot
// A 2D KD-tree for O(log n) nearest-neighbour queries.
// Used by TSPSolver (nearest-neighbour construction, 2-opt pruning)
// and VoronoiStippler (nearest-point lookups).

import Foundation

/// A 2-dimensional KD-tree over StipplePoint values.
/// Build once with `KDTree(points:)`, then query with `nearest(to:)`.
nonisolated public struct KDTree: Sendable {

    // MARK: — Node storage (flat array for cache friendliness)
    private struct Node {
        let pointIndex: Int  // index into the original points array
        let x: Float
        let y: Float
        var left: Int  // index in nodes array; -1 = leaf
        var right: Int
    }

    private let points: [StipplePoint]
    private var nodes: [Node] = []
    private var rootIndex: Int = -1

    // MARK: — Build
    public init(points: [StipplePoint]) {
        self.points = points
        guard !points.isEmpty else { return }
        // Build flat index array and construct tree
        var indices = Array(0..<points.count)
        rootIndex = build(indices: &indices, depth: 0)
    }

    private mutating func build(indices: inout [Int], depth: Int) -> Int {
        guard !indices.isEmpty else { return -1 }
        let axis = depth % 2
        indices.sort { axis == 0 ? points[$0].x < points[$1].x : points[$0].y < points[$1].y }
        let median = indices.count / 2
        let idx = indices[median]
        let nodeIdx = nodes.count
        // Append placeholder
        nodes.append(Node(pointIndex: idx, x: points[idx].x, y: points[idx].y, left: -1, right: -1))
        var leftSlice = Array(indices[..<median])
        var rightSlice = Array(indices[(median + 1)...])
        let leftChild = build(indices: &leftSlice, depth: depth + 1)
        let rightChild = build(indices: &rightSlice, depth: depth + 1)
        nodes[nodeIdx].left = leftChild
        nodes[nodeIdx].right = rightChild
        return nodeIdx
    }

    // MARK: — Nearest neighbour query

    /// Returns the index (into the original points array) of the point nearest to `query`,
    /// optionally excluding a set of already-visited indices.
    public func nearestIndex(to query: StipplePoint, excluding visited: Set<Int> = []) -> Int? {
        guard rootIndex >= 0 else { return nil }
        var bestIndex: Int = -1
        var bestDist: Float = .infinity
        search(nodeIdx: rootIndex, query: query, depth: 0, bestIndex: &bestIndex, bestDist: &bestDist, excluding: visited)
        return bestIndex == -1 ? nil : bestIndex
    }

    private func search(
        nodeIdx: Int,
        query: StipplePoint,
        depth: Int,
        bestIndex: inout Int,
        bestDist: inout Float,
        excluding: Set<Int>
    ) {
        guard nodeIdx >= 0 else { return }
        let node = nodes[nodeIdx]
        if !excluding.contains(node.pointIndex) {
            let d = query.distanceSquared(to: StipplePoint(x: node.x, y: node.y))
            if d < bestDist {
                bestDist = d
                bestIndex = node.pointIndex
            }
        }
        let axis = depth % 2
        let diff: Float = axis == 0 ? query.x - node.x : query.y - node.y
        let (near, far) = diff <= 0 ? (node.left, node.right) : (node.right, node.left)
        search(nodeIdx: near, query: query, depth: depth + 1, bestIndex: &bestIndex, bestDist: &bestDist, excluding: excluding)
        // Only search far side if it could contain a closer point
        if diff * diff < bestDist {
            search(nodeIdx: far, query: query, depth: depth + 1, bestIndex: &bestIndex, bestDist: &bestDist, excluding: excluding)
        }
    }

    // MARK: — K-nearest neighbours (for 2-opt pruning)

    /// Returns indices of the `k` nearest points to `query` (sorted nearest-first).
    public func kNearest(to query: StipplePoint, k: Int) -> [Int] {
        guard rootIndex >= 0, k > 0 else { return [] }
        // Use a max-heap (sorted array) to track k-best
        var heap: [(dist: Float, idx: Int)] = []
        kSearch(nodeIdx: rootIndex, query: query, depth: 0, k: k, heap: &heap)
        return heap.sorted { $0.dist < $1.dist }.map(\.idx)
    }

    private func kSearch(
        nodeIdx: Int,
        query: StipplePoint,
        depth: Int,
        k: Int,
        heap: inout [(dist: Float, idx: Int)]
    ) {
        guard nodeIdx >= 0 else { return }
        let node = nodes[nodeIdx]
        let d = query.distanceSquared(to: StipplePoint(x: node.x, y: node.y))
        if heap.count < k {
            heap.append((d, node.pointIndex))
            heap.sort { $0.dist > $1.dist } // max at top
        } else if let maxDist = heap.first?.dist, d < maxDist {
            heap[0] = (d, node.pointIndex)
            heap.sort { $0.dist > $1.dist }
        }
        let axis = depth % 2
        let diff: Float = axis == 0 ? query.x - node.x : query.y - node.y
        let (near, far) = diff <= 0 ? (node.left, node.right) : (node.right, node.left)
        kSearch(nodeIdx: near, query: query, depth: depth + 1, k: k, heap: &heap)
        let worstBest = heap.first?.dist ?? .infinity
        if diff * diff < worstBest || heap.count < k {
            kSearch(nodeIdx: far, query: query, depth: depth + 1, k: k, heap: &heap)
        }
    }
}
