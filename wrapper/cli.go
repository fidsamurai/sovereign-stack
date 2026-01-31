package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"wrapper/infra"
	"wrapper/prereqs"
)

func handle(err error) {
	if err != nil {
		fmt.Printf("Critical Error: %v\n", err)
		os.Exit(1)
	}
}

func main() {

	if len(os.Args) < 2 {
		flag.Usage()
		return
	}

	switch os.Args[1] {
	case "prereqs":
		//Settings flags for the prereqs
		prereqsCmd := flag.NewFlagSet("prereqs", flag.ExitOnError)
		prereqsCmd.Parse(os.Args[2:])
		//Running the functions
		handle(prereqs.CheckCommands())
		handle(prereqs.CheckConfigs())
	case "infra":
		//Setting flags for the CLI
		infraCmd := flag.NewFlagSet("infra", flag.ExitOnError)
		firstTime := infraCmd.Bool("first-time", false, "Set to true for first deployment")
		modules := infraCmd.String("modules", "all", "Comma separated list of modules to deploy for eg. dev-dr-network,prod-primary-alb or all for all modules")

		infraCmd.Parse(os.Args[2:])

		isFirstTime := *firstTime
		modulesList := strings.Split(*modules, ",")

		//Running the functions
		handle(infra.SSHKeys(isFirstTime))
		handle(infra.Init(isFirstTime))
		handle(infra.Apply(isFirstTime, modulesList))
	default:
		flag.Usage()
	}
}
