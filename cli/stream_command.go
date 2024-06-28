package cli

import (
	"fmt"
	"os"
	"strings"
	"text/tabwriter"
	"time"

	"github.com/AlecAivazis/survey/v2"
	"github.com/choria-io/fisk"

	"sequin-cli/api"
	"sequin-cli/context"
)

// AddStreamCommands adds all stream-related commands to the given app
func AddStreamCommands(app *fisk.Application, config *Config) {
	stream := app.Command("stream", "Stream related commands")

	addCheat("stream", stream)

	stream.Command("ls", "List streams").Action(func(c *fisk.ParseContext) error {
		return streamLs(c, config)
	})

	infoCmd := stream.Command("info", "Show stream info").Action(func(c *fisk.ParseContext) error {
		return streamInfo(c, config)
	})
	infoCmd.Arg("stream-id", "ID of the stream to show info for").StringVar(&config.StreamID)
}

func streamLs(_ *fisk.ParseContext, config *Config) error {
	ctx, err := context.LoadContext(config.ContextName)
	if err != nil {
		return err
	}

	streams, err := api.FetchStreams(ctx)
	if err != nil {
		return err
	}

	// Create a new tabwriter
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)

	// Print header
	fmt.Fprintln(w, "ID\tIndex\tConsumers\tMessages\tCreated At\tUpdated At")
	fmt.Fprintln(w, "--\t-----\t---------\t--------\t----------\t----------")

	// Print each stream
	for _, s := range streams {
		fmt.Fprintf(w, "%s\t%d\t%d\t%d\t%s\t%s\n",
			s.ID, s.Idx, s.ConsumerCount, s.MessageCount,
			s.CreatedAt.Format(time.RFC3339),
			s.UpdatedAt.Format(time.RFC3339))
	}

	// Flush the tabwriter
	w.Flush()

	return nil
}

func streamInfo(_ *fisk.ParseContext, config *Config) error {
	if config.StreamID == "" {
		ctx, err := context.LoadContext(config.ContextName)
		if err != nil {
			return err
		}

		streams, err := api.FetchStreams(ctx)
		if err != nil {
			return err
		}

		prompt := &survey.Select{
			Message: "Choose a stream:",
			Options: make([]string, len(streams)),
			Filter: func(filterValue string, optValue string, index int) bool {
				return strings.Contains(strings.ToLower(optValue), strings.ToLower(filterValue))
			},
		}
		for i, s := range streams {
			prompt.Options[i] = fmt.Sprintf("%s (Index: %d)", s.ID, s.Idx)
		}

		var choice string
		err = survey.AskOne(prompt, &choice)
		if err != nil {
			return err
		}

		config.StreamID = strings.Split(choice, " ")[0]
	}

	return displayStreamInfo(config)
}

func displayStreamInfo(config *Config) error {
	ctx, err := context.LoadContext(config.ContextName)
	if err != nil {
		return err
	}

	streamResponse, err := api.FetchStreamInfo(config.StreamID, ctx)
	if err != nil {
		return err
	}

	// Display stream info
	fmt.Printf("Stream Information:\n")
	fmt.Printf("ID: %s\n", streamResponse.Stream.ID)
	fmt.Printf("Index: %d\n", streamResponse.Stream.Idx)
	fmt.Printf("Consumers: %d\n", streamResponse.Stream.ConsumerCount)
	fmt.Printf("Messages: %d\n", streamResponse.Stream.MessageCount)
	fmt.Printf("Created At: %s\n", streamResponse.Stream.CreatedAt.Format(time.RFC3339))
	fmt.Printf("Updated At: %s\n", streamResponse.Stream.UpdatedAt.Format(time.RFC3339))

	return nil
}