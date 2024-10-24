defmodule Sequin.Consumers.HttpPullConsumer do
  @moduledoc false
  use Sequin.ConfigSchema

  import Ecto.Changeset
  import Ecto.Query

  alias __MODULE__
  alias Sequin.Accounts.Account
  alias Sequin.Consumers.RecordConsumerState
  alias Sequin.Consumers.SequenceFilter
  alias Sequin.Consumers.SourceTable
  alias Sequin.Databases.Sequence
  alias Sequin.Replication.PostgresReplicationSlot

  @derive {Jason.Encoder,
           only: [
             :account_id,
             :ack_wait_ms,
             :id,
             :inserted_at,
             :max_ack_pending,
             :max_deliver,
             :max_waiting,
             :message_kind,
             :name,
             :record_consumer_state,
             :updated_at,
             :status
           ]}
  typed_schema "http_pull_consumers" do
    field :name, :string
    field :backfill_completed_at, :utc_datetime_usec
    field :ack_wait_ms, :integer, default: 30_000
    field :max_ack_pending, :integer, default: 10_000
    field :max_deliver, :integer
    field :max_waiting, :integer, default: 20
    field :message_kind, Ecto.Enum, values: [:event, :record], default: :record
    field :status, Ecto.Enum, values: [:active, :disabled], default: :active
    field :seq, :integer, read_after_writes: true

    embeds_many :source_tables, SourceTable, on_replace: :delete
    embeds_one :record_consumer_state, RecordConsumerState, on_replace: :delete

    # Sequence
    belongs_to :sequence, Sequence
    embeds_one :sequence_filter, SequenceFilter, on_replace: :delete

    belongs_to :account, Account
    belongs_to :replication_slot, PostgresReplicationSlot

    has_one :postgres_database, through: [:replication_slot, :postgres_database]

    field :health, :map, virtual: true

    timestamps()
  end

  def create_changeset(consumer, attrs) do
    consumer
    |> cast(attrs, [
      :ack_wait_ms,
      :max_ack_pending,
      :max_deliver,
      :max_waiting,
      :message_kind,
      :name,
      :backfill_completed_at,
      :replication_slot_id,
      :status,
      :sequence_id
    ])
    |> Sequin.Changeset.cast_embed(:source_tables)
    |> cast_embed(:record_consumer_state)
    |> cast_embed(:sequence_filter, with: &SequenceFilter.create_changeset/2)
    # TODO: add sequence_id requirement
    |> validate_required([:name, :status])
    |> foreign_key_constraint(:sequence_id, name: "postgres_databases_account_id_fkey")
    |> unique_constraint([:account_id, :name], error_key: :name)
    |> check_constraint(:sequence_filter, name: "sequence_filter_check")
    |> Sequin.Changeset.validate_name()
  end

  def update_changeset(consumer, attrs) do
    consumer
    |> cast(attrs, [
      :ack_wait_ms,
      :max_ack_pending,
      :max_deliver,
      :max_waiting,
      :backfill_completed_at,
      :status
    ])
    |> Sequin.Changeset.cast_embed(:source_tables)
    |> cast_embed(:record_consumer_state)
  end

  def where_account_id(query \\ base_query(), account_id) do
    from([consumer: c] in query, where: c.account_id == ^account_id)
  end

  def where_replication_slot_id(query \\ base_query(), replication_slot_id) do
    from([consumer: c] in query, where: c.replication_slot_id == ^replication_slot_id)
  end

  def where_id(query \\ base_query(), id) do
    from([consumer: c] in query, where: c.id == ^id)
  end

  def where_name(query \\ base_query(), name) do
    from([consumer: c] in query, where: c.name == ^name)
  end

  def where_sequence_id(query \\ base_query(), sequence_id) do
    from([consumer: c] in query, where: c.sequence_id == ^sequence_id)
  end

  def where_id_or_name(query \\ base_query(), id_or_name) do
    if Sequin.String.is_uuid?(id_or_name) do
      where_id(query, id_or_name)
    else
      where_name(query, id_or_name)
    end
  end

  def where_status(query \\ base_query(), status) do
    from([consumer: c] in query, where: c.status == ^status)
  end

  def where_table_producer(query \\ base_query()) do
    from([consumer: c] in query,
      where:
        fragment("?->>'producer' = ?", c.record_consumer_state, "table_and_wal") and
          c.message_kind == :record
    )
  end

  defp base_query(query \\ __MODULE__) do
    from(c in query, as: :consumer)
  end

  @backfill_completed_at_threshold :timer.minutes(5)
  def should_delete_acked_messages?(consumer, now \\ DateTime.utc_now())

  def should_delete_acked_messages?(%HttpPullConsumer{backfill_completed_at: nil}, _now), do: false

  def should_delete_acked_messages?(%HttpPullConsumer{backfill_completed_at: backfill_completed_at}, now) do
    backfill_completed_at
    |> DateTime.add(@backfill_completed_at_threshold, :millisecond)
    |> DateTime.compare(now) == :lt
  end
end
