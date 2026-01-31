defmodule PubsubChat.MixProject do
  use Mix.Project

  def project do
    [
      app: :pubsub_chat,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Docs
      name: "PubsubChat",
      source_url: "https://github.com/yourusername/pubsub_chat",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PubsubChat.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end
end
