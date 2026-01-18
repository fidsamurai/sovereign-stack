package main

import (
	"flag"
	"fmt"
	"os"
	"wrapper/infra"
	"wrapper/prereqs"
)

func main() {

	if len(os.Args) < 2 {
		flag.Usage()
		return
	}

	switch os.Args[1] {
	case "prereqs":
		prereqs.Check()
	case "infra":
		if len(os.Args) < 3 {
			fmt.Println("Error: The infra module requires the argument --first-time=true/false")
			return
		}
		infra.SSHKeys()
		infra.Init()
		infra.Apply(os.Args[2])
	default:
		flag.Usage()
	}
}
