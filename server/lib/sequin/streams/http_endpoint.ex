defmodule Sequin.Streams.HttpEndpoint do
  use Sequin.ConfigSchema

  import Ecto.Changeset
  import Ecto.Query

  alias __MODULE__

  @derive {Jason.Encoder, only: [:id, :name, :base_url, :headers, :account_id, :inserted_at, :updated_at]}
  typed_schema "http_endpoints" do
    field :name, :string
    field :base_url, :string
    field :headers, :map, default: %{}

    belongs_to :account, Sequin.Accounts.Account

    has_many :consumers, Sequin.Streams.Consumer

    timestamps()
  end

  def changeset(http_endpoint, attrs) do
    http_endpoint
    |> cast(attrs, [:name, :base_url, :headers, :account_id])
    |> validate_required([:base_url, :account_id])
    |> validate_base_url()
    |> foreign_key_constraint(:account_id)
  end

  def where_account_id(query \\ base_query(), account_id) do
    from([http_endpoint: he] in query, where: he.account_id == ^account_id)
  end

  defp validate_base_url(changeset) do
    case get_change(changeset, :base_url) do
      nil ->
        changeset

      base_url ->
        case URI.parse(base_url) do
          %URI{scheme: scheme, host: host} when is_binary(scheme) and is_binary(host) ->
            changeset

          _ ->
            add_error(changeset, :base_url, "must be a valid URL with scheme and host")
        end
    end
  end

  defp base_query(query \\ HttpEndpoint) do
    from(he in query, as: :http_endpoint)
  end
end