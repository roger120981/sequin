<script lang="ts">
  import { ExternalLink } from "lucide-svelte";
  import { Card, CardContent, CardTitle } from "$lib/components/ui/card";
  import CardHeader from "$lib/components/ui/card/card-header.svelte";
  import { Button } from "$lib/components/ui/button";
  import type { KinesisConsumer } from "../../consumers/types";

  export let consumer: KinesisConsumer;

  var awsConsoleUrl = "#";

  $: {
    const arnMatch =
      consumer.sink.stream_arn &&
      consumer.sink.stream_arn.match(
        /^arn:aws:kinesis:([^:]+):[^:]+:stream\/(.+)$/,
      );
    if (arnMatch) {
      const [, region, streamName] = arnMatch;
      awsConsoleUrl = `https://${region}.console.aws.amazon.com/kinesis/home?region=${region}#/streams/details/${encodeURIComponent(streamName)}`;
    } else {
      awsConsoleUrl = `https://${consumer.sink.region}.console.aws.amazon.com/kinesis/home?region=${consumer.sink.region}#/streams/details`;
    }
  }
</script>

<Card>
  <CardContent class="p-6">
    <div class="flex justify-between items-center mb-4">
      <h2 class="text-lg font-semibold">Kinesis Configuration</h2>
      <div class="flex gap-2">
        <a href={awsConsoleUrl} target="_blank" rel="noopener noreferrer">
          <Button variant="outline" size="sm">
            <ExternalLink class="h-4 w-4 mr-2" />
            View in AWS Console
          </Button>
        </a>
      </div>
    </div>

    <div class="flex flex-col gap-4">
      <div class="grid grid-cols-2 gap-4">
        <div>
          <span class="text-sm text-gray-500">Region</span>
          <div class="mt-2">
            <span
              class="font-mono bg-slate-50 px-2 py-1 border border-slate-100 rounded-md whitespace-nowrap"
            >
              {consumer.sink.region}</span
            >
          </div>
        </div>
      </div>

      {#if consumer.sink.use_task_role}
        <div class="mt-4">
          <div>
            <span class="text-sm text-gray-500">AWS Credentials</span>
            <div class="mt-2">
              <span class="text-sm text-green-600"
                >Loaded from task role, environment, or AWS profile</span
              >
            </div>
          </div>
        </div>
      {/if}
    </div>
  </CardContent>
</Card>

<Card>
  <CardHeader>
    <CardTitle>Routing</CardTitle>
  </CardHeader>
  <CardContent>
    <div>
      <span class="text-sm text-gray-500">Stream ARN</span>
      <div class="mt-2">
        <span
          class="font-mono bg-slate-50 pl-1 pr-4 py-1 border border-slate-100 rounded-md whitespace-nowrap"
        >
          {#if consumer.routing_id}
            Determined by <a
              href={`/functions/${consumer.routing_id}`}
              data-phx-link="redirect"
              data-phx-link-state="push"
              class="underline">router</a
            >
            <ExternalLink class="h-4 w-4 inline" />
          {:else}
            {consumer.sink.stream_arn}
          {/if}
        </span>
      </div>
    </div>
    {#if consumer.routing}
      <div class="mt-2">
        <span class="text-sm text-gray-500">Router</span>
        <div class="mt-2">
          <pre
            class="font-mono bg-slate-50 p-2 border border-slate-100 rounded-md text-sm overflow-x-auto"><code
              >{consumer.routing.function.code}</code
            ></pre>
        </div>
      </div>
    {/if}
  </CardContent>
</Card>
