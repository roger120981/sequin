defmodule Sequin.Consumers.KafkaDestination do
  @moduledoc false
  use Ecto.Schema
  use TypedEctoSchema

  import Ecto.Changeset

  alias __MODULE__

  @derive {Jason.Encoder, only: [:hosts, :topic]}
  typed_embedded_schema do
    field :type, Ecto.Enum, values: [:kafka], default: :kafka
    field :hosts, :string
    field :username, :string
    field :password, Sequin.Encrypted.Binary
    field :tls, :boolean, default: false
    field :topic, :string

    field :ssl_cert_file, :string
    field :ssl_key_file, :string
    field :ssl_ca_cert_file, :string
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :hosts,
      :username,
      :password,
      :tls,
      :topic,
      :ssl_cert_file,
      :ssl_key_file,
      :ssl_ca_cert_file
    ])
    |> validate_required([:hosts, :topic])
    |> validate_length(:topic, max: 255)
    |> validate_hosts()
    |> validate_ssl_files()
  end

  defp validate_hosts(changeset) do
    hosts = get_field(changeset, :hosts)

    if hosts do
      hosts_valid? =
        hosts
        |> String.split(",")
        |> Enum.all?(fn host ->
          case String.split(host, ":") do
            [_host, port] ->
              case Integer.parse(port) do
                {port_num, ""} -> port_num > 0 and port_num < 65_536
                _ -> false
              end

            _ ->
              false
          end
        end)

      if hosts_valid? do
        changeset
      else
        add_error(changeset, :hosts, "must be a comma-separated list of host:port pairs with valid ports (1-65535)")
      end
    else
      changeset
    end
  end

  defp validate_ssl_files(changeset) do
    if get_field(changeset, :tls) do
      changeset
      |> validate_required([:ssl_cert_file, :ssl_key_file, :ssl_ca_cert_file])
      |> validate_ssl_file_exists(:ssl_cert_file)
      |> validate_ssl_file_exists(:ssl_key_file)
      |> validate_ssl_file_exists(:ssl_ca_cert_file)
    else
      changeset
    end
  end

  defp validate_ssl_file_exists(changeset, field) do
    case get_field(changeset, field) do
      nil ->
        changeset

      path ->
        if File.exists?(path) do
          changeset
        else
          add_error(changeset, field, "file does not exist")
        end
    end
  end

  def kafka_url(destination, opts \\ []) do
    obscure_password = Keyword.get(opts, :obscure_password, true)

    auth = build_auth_string(destination, obscure_password)
    "#{protocol(destination)}#{auth}#{destination.hosts}"
  end

  defp build_auth_string(%KafkaDestination{username: nil, password: nil}, _obscure), do: ""

  defp build_auth_string(%KafkaDestination{username: nil, password: password}, obscure) do
    "#{format_password(password, obscure)}@"
  end

  defp build_auth_string(%KafkaDestination{username: username, password: nil}, _obscure) do
    "#{username}@"
  end

  defp build_auth_string(%KafkaDestination{username: username, password: password}, obscure) do
    "#{username}:#{format_password(password, obscure)}@"
  end

  defp format_password(_, true), do: "******"
  defp format_password(password, false), do: password

  defp protocol(%KafkaDestination{tls: true}), do: "kafka+ssl://"
  defp protocol(%KafkaDestination{tls: false}), do: "kafka://"
end