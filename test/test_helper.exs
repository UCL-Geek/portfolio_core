ExUnit.start()

# Define mocks for all ports
Mox.defmock(PortfolioCore.Mocks.VectorStore, for: PortfolioCore.Ports.VectorStore)
Mox.defmock(PortfolioCore.Mocks.GraphStore, for: PortfolioCore.Ports.GraphStore)
Mox.defmock(PortfolioCore.Mocks.DocumentStore, for: PortfolioCore.Ports.DocumentStore)
Mox.defmock(PortfolioCore.Mocks.Embedder, for: PortfolioCore.Ports.Embedder)
Mox.defmock(PortfolioCore.Mocks.LLM, for: PortfolioCore.Ports.LLM)
Mox.defmock(PortfolioCore.Mocks.Chunker, for: PortfolioCore.Ports.Chunker)
Mox.defmock(PortfolioCore.Mocks.Retriever, for: PortfolioCore.Ports.Retriever)
Mox.defmock(PortfolioCore.Mocks.Reranker, for: PortfolioCore.Ports.Reranker)

Application.put_env(:portfolio_core, :mocks, %{
  vector_store: PortfolioCore.Mocks.VectorStore,
  graph_store: PortfolioCore.Mocks.GraphStore,
  document_store: PortfolioCore.Mocks.DocumentStore,
  embedder: PortfolioCore.Mocks.Embedder,
  llm: PortfolioCore.Mocks.LLM,
  chunker: PortfolioCore.Mocks.Chunker,
  retriever: PortfolioCore.Mocks.Retriever,
  reranker: PortfolioCore.Mocks.Reranker
})
