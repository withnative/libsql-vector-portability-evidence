use libsql::Builder;

#[tokio::main]
async fn main() {
    let output = std::env::args()
        .nth(1)
        .expect("usage: libsql-vector-portability-embedded OUTPUT.db");

    let db = Builder::new_local(output).build().await.unwrap();
    let conn = db.connect().unwrap();

    conn.execute(
        "CREATE TABLE embeddings(id INTEGER PRIMARY KEY, v F32_BLOB(2))",
        (),
    )
    .await
    .unwrap();
    conn.execute(
        "INSERT INTO embeddings(v) VALUES(vector32('[1.0,2.0]'))",
        (),
    )
    .await
    .unwrap();
    conn.execute(
        "CREATE INDEX idx_emb_vec ON embeddings(libsql_vector_idx(v))",
        (),
    )
    .await
    .unwrap();
}
