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
Mox.defmock(PortfolioCore.Mocks.Router, for: PortfolioCore.Ports.Router)
Mox.defmock(PortfolioCore.Mocks.Cache, for: PortfolioCore.Ports.Cache)
Mox.defmock(PortfolioCore.Mocks.Pipeline, for: PortfolioCore.Ports.Pipeline)
Mox.defmock(PortfolioCore.Mocks.Agent, for: PortfolioCore.Ports.Agent)
Mox.defmock(PortfolioCore.Mocks.Tool, for: PortfolioCore.Ports.Tool)

Application.put_env(:portfolio_core, :mocks, %{
  vector_store: PortfolioCore.Mocks.VectorStore,
  graph_store: PortfolioCore.Mocks.GraphStore,
  document_store: PortfolioCore.Mocks.DocumentStore,
  embedder: PortfolioCore.Mocks.Embedder,
  llm: PortfolioCore.Mocks.LLM,
  chunker: PortfolioCore.Mocks.Chunker,
  retriever: PortfolioCore.Mocks.Retriever,
  reranker: PortfolioCore.Mocks.Reranker,
  router: PortfolioCore.Mocks.Router,
  cache: PortfolioCore.Mocks.Cache,
  pipeline: PortfolioCore.Mocks.Pipeline,
  agent: PortfolioCore.Mocks.Agent,
  tool: PortfolioCore.Mocks.Tool
})
