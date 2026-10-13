-- Supabase setup for the RAG demo, FREE path (Gemini embeddings, 3072 dimensions)
-- Run in Supabase Dashboard > SQL Editor. This REPLACES the earlier 1536-dim table
-- (safe if you have not ingested anything yet).

drop function if exists match_rag_demo_documents(vector, int, jsonb);
drop table if exists rag_demo_documents;

create extension if not exists vector;

create table rag_demo_documents (
  id bigserial primary key,
  content text,
  metadata jsonb,
  embedding vector(3072)   -- gemini-embedding-001 default output size
);

-- Keep the table private; n8n uses the service_role key which bypasses RLS
alter table rag_demo_documents enable row level security;

create or replace function match_rag_demo_documents (
  query_embedding vector(3072),
  match_count int default 4,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    rag_demo_documents.id,
    rag_demo_documents.content,
    rag_demo_documents.metadata,
    1 - (rag_demo_documents.embedding <=> query_embedding) as similarity
  from rag_demo_documents
  where rag_demo_documents.metadata @> filter
  order by rag_demo_documents.embedding <=> query_embedding
  limit match_count;
end;
$$;
-- No vector index on purpose: pgvector indexes cap at 2000 dims, and exact search
-- is instant at demo scale (tens or hundreds of chunks).
