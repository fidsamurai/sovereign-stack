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
		envs := prereqsCmd.String("envs", "all", "Comma separated list of environments to check for eg. dev-dr,prod-primary or all for all modules")
		prereqsCmd.Parse(os.Args[2:])
		envsList := strings.Split(*envs, ",")
		//Running the functions
		handle(prereqs.CheckCommands())
		handle(prereqs.CheckConfigs(envsList))
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
	case "state-refresh":
		stateRefreshCmd := flag.NewFlagSet("state-refresh", flag.ExitOnError)
		modules := stateRefreshCmd.String("modules", "all", "Comma separated list of modules to refresh state for eg. dev-dr-network,prod-primary-alb or all for all modules")
		stateRefreshCmd.Parse(os.Args[2:])
		modulesList := strings.Split(*modules, ",")
		handle(infra.StateRefresh(modulesList))
	case "validate":
		validateCmd := flag.NewFlagSet("validate", flag.ExitOnError)
		modules := validateCmd.String("modules", "all", "Comma separated list of modules to validate for eg. dev-dr-network,prod-primary-alb or all for all modules")
		validateCmd.Parse(os.Args[2:])
		modulesList := strings.Split(*modules, ",")
		handle(infra.Validate(modulesList))
	case "destroy":
		destroyCmd := flag.NewFlagSet("destroy", flag.ExitOnError)
		modules := destroyCmd.String("modules", "all", "Comma separated list of modules to destroy for eg. dev-dr-network,prod-primary-alb or all for all modules")
		destroyCmd.Parse(os.Args[2:])
		modulesList := strings.Split(*modules, ",")
		handle(infra.Destroy(modulesList))
	default:
		flag.Usage()
	}
}
