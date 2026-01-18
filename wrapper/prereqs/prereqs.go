package prereqs

import (
	"fmt"
	"os/exec"
)

func Check() {
	//List of prerequisites to check
	prereqs := []string{"terragrunt", "aws"}

	for _, command := range prereqs {
		path, err := exec.LookPath(command)
		if err != nil {
			fmt.Printf("%v is not installed. Please install it and try again.\n", command)
			return
		}
		fmt.Printf("%v is installed at %v\n", command, path)
	}
}
