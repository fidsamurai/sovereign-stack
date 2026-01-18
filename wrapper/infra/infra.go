package infra

import (
	"fmt"
	"os/exec"
)

func SSHKeys() {
	// Create the required keys in the /home/folder
	keys_to_make := []string{"cplane_pri", "cplane_dr", "worker_pri", "worker_dr", "jump_server"}

	for _, key := range keys_to_make {
		sshkeys := exec.Command("ssh-keygen", "-t", "ed25519", "-f", "~/.ssh/"+key+".pem", "-C", key)
		output, err := sshkeys.CombinedOutput()
		if err != nil {
			fmt.Println("Error creating SSH Key: ", err)
		}
		fmt.Println("SSH Key created successfully", string(output))
	}

}

func Init() {
	// Terragrunt Init
	terragrunt := exec.Command("terragrunt", "init")
	terragrunt.Dir = "../terraform/"
	fmt.Printf("Running Terragrunt Init in %s\n", terragrunt.Dir)
	output, err := terragrunt.CombinedOutput()

	if err != nil {
		fmt.Println("Error running terragrunt init: ", err)
	}

	fmt.Println("Terragrunt Init completed successfully", string(output))
}

func GetVars() {
	//User input on variables to be written to the env_vars of each module.

}

func Apply(first_time string) {
	//Check if this is a first time deployment and run terragrunt plan or apply
	if first_time == "--first-time=false" {
		plan := exec.Command("terragrunt", "plan")
		plan.Dir = "../terraform/"
		fmt.Printf("Running Terragrunt Plan in %s\n", plan.Dir)
		output, err := plan.CombinedOutput()
		if err != nil {
			fmt.Println("Error running terragrunt plan: ", err)
		}
		fmt.Println("Terragrunt Plan completed successfully", string(output))
		fmt.Println("Type 'true' if you would like to continue the deployment: ")
		var approval bool
		fmt.Scanf("%t", &approval)
		if approval != true {
			fmt.Println("Deployment cancelled")
			return
		} else {
			apply := exec.Command("terragrunt", "apply", "-auto-approve")
			apply.Dir = "../terraform/"
			fmt.Printf("Running Terragrunt Apply in %s\n", apply.Dir)
			output, err := apply.CombinedOutput()
			if err != nil {
				fmt.Println("Error running terragrunt apply: ", err)
			}
			fmt.Println("Terragrunt Apply completed successfully", string(output))
		}
	} else {
		apply := exec.Command("terragrunt", "apply", "-auto-approve")
		apply.Dir = "../terraform/"
		fmt.Printf("Running Terragrunt Apply in %s\n", apply.Dir)
		output, err := apply.CombinedOutput()
		if err != nil {
			fmt.Println("Error running terragrunt apply: ", err)
		}
		fmt.Println("Terragrunt Apply completed successfully", string(output))
	}
}
