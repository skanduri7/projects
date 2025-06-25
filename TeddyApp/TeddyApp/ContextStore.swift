//
//  ContextStore.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/25/25.
//
import Foundation
import SQLite3          // system SQLite
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Tiny FIFO DB that stores recent Fusion items and FTS5-indexes `text`.
final class ContextStore {

    static let shared = ContextStore(keepSeconds: 10)   // retain 10 s
    private let keep: TimeInterval
    private let db : OpaquePointer!
    private let q  = DispatchQueue(label: "ctx.db")     // serialise access

    // MARK: - init  (open :memory: and build schema)
    private init(keepSeconds: TimeInterval) {
        self.keep = keepSeconds

        var handle: OpaquePointer?
        sqlite3_open(":memory:", &handle)
        db = handle

        let sql = """
        PRAGMA journal_mode = WAL;
        CREATE TABLE IF NOT EXISTS snapshot(
            id    INTEGER PRIMARY KEY AUTOINCREMENT,
            time  REAL,
            text  TEXT,
            role  TEXT,
            x REAL, y REAL, w REAL, h REAL
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS snapshot_fts
            USING fts5(text, content='snapshot', content_rowid='id');
        CREATE TRIGGER IF NOT EXISTS snapshot_ai AFTER INSERT ON snapshot
            BEGIN INSERT INTO snapshot_fts(rowid,text) VALUES(new.id,new.text); END;
        CREATE TRIGGER IF NOT EXISTS snapshot_ad AFTER DELETE ON snapshot
            BEGIN INSERT INTO snapshot_fts(snapshot_fts, rowid, text)
                 VALUES('delete', old.id, old.text); END;
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    deinit { sqlite3_close(db) }

    // MARK: - insert one fused Item
    func insert(_ item: FusionEngine.Item) {
        q.async {
            let stmt = """
            INSERT INTO snapshot(time,text,role,x,y,w,h)
            VALUES(?,?,?,?,?,?,?);
            """
            var s: OpaquePointer?
            sqlite3_prepare_v2(self.db, stmt, -1, &s, nil)

            sqlite3_bind_double(s, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text  (s, 2, item.text, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text  (s, 3, item.role, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(s, 4, Double(item.rect.minX))
            sqlite3_bind_double(s, 5, Double(item.rect.minY))
            sqlite3_bind_double(s, 6, Double(item.rect.width))
            sqlite3_bind_double(s, 7, Double(item.rect.height))

            sqlite3_step(s)
            sqlite3_finalize(s)
            self.prune()
        }
    }

    // MARK: - delete rows older than `keep` seconds
    private func prune() {
        let cutoff = Date().timeIntervalSince1970 - keep
        sqlite3_exec(db,
            "DELETE FROM snapshot WHERE time < \(cutoff);", nil, nil, nil)
    }

    // MARK: - full-text search (MATCH query)
    /// Returns newest matches first (max `limit` rows)
    func search(_ query: String, limit: Int = 20) -> [FusionEngine.Item] {
        var out: [FusionEngine.Item] = []
        q.sync {
            let stmt = """
            SELECT s.text,s.role,s.x,s.y,s.w,s.h
              FROM snapshot_fts f
              JOIN snapshot s ON s.id = f.rowid
             WHERE snapshot_fts MATCH ?
             ORDER BY s.time DESC
             LIMIT ?;
            """
            var st: OpaquePointer?
            sqlite3_prepare_v2(db, stmt, -1, &st, nil)
            sqlite3_bind_text (st, 1, query, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int  (st, 2, Int32(limit))

            while sqlite3_step(st) == SQLITE_ROW {
                let txt  = String(cString: sqlite3_column_text(st,0))
                let role = String(cString: sqlite3_column_text(st,1))
                let x = CGFloat(sqlite3_column_double(st,2))
                let y = CGFloat(sqlite3_column_double(st,3))
                let w = CGFloat(sqlite3_column_double(st,4))
                let h = CGFloat(sqlite3_column_double(st,5))

                out.append(.init(text: txt,
                                 rect: CGRect(x: x,y: y,width: w,height: h),
                                 src: role.isEmpty ? .ocr : .ax,
                                 role: role))
            }
            sqlite3_finalize(st)
        }
        return out
    }
}
