package infra

import (
	"fmt"
	"os"
	"os/exec"
)

// SSHKeys generates required keys. Note: Changed firstTime to bool.
func SSHKeys(firstTime bool) error {
	if !firstTime {
		return nil
	}

	keys := []string{"dev_cplane_pri", "dev_cplane_dr", "dev_worker_pri", "dev_worker_dr", "dev_jump_server",
		"prod_cplane_pri", "prod_cplane_dr", "prod_worker_pri", "prod_worker_dr", "prod_jump_server"}

	for _, key := range keys {
		// Note: "~" shell expansion doesn't always work in exec.Command; os.UserHomeDir is safer.
		home, _ := os.UserHomeDir()
		path := fmt.Sprintf("%s/.ssh/%s.pem", home, key)

		// Fixed the N argument and path handling
		cmd := exec.Command("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", path, "-C", key)
		if output, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("failed to create SSH Key %s: %w (output: %s)", key, err, string(output))
		}
		fmt.Printf("✅ SSH Key created: %s\n", key)
	}
	return nil
}

func Init(firstTime bool) error {
	if !firstTime {
		return nil
	}

	cmd := exec.Command("terragrunt", "init")
	cmd.Dir = "../terraform/"
	fmt.Printf("🚀 Running Terragrunt Init in %s\n", cmd.Dir)

	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("terragrunt init failed: %w\n%s", err, string(output))
	}
	fmt.Println("✅ Terragrunt Init completed.")
	return nil
}

func Apply(firstTime bool) error {
	workingDir := "../terraform/"

	// If not first time, we do a manual Plan + Approval check
	if !firstTime {
		plan := exec.Command("terragrunt", "plan")
		plan.Dir = workingDir
		fmt.Println("🔍 Running Terragrunt Plan...")

		if out, err := plan.CombinedOutput(); err != nil {
			return fmt.Errorf("plan failed: %w\n%s", err, string(out))
		}

		fmt.Print("❓ Plan successful. Type 'true' to apply: ")
		var approval bool
		fmt.Scanf("%t", &approval)
		if !approval {
			return fmt.Errorf("deployment cancelled by user")
		}
	}

	// Actual Apply (runs for firstTime=true OR after approval)
	apply := exec.Command("terragrunt", "apply", "-auto-approve")
	apply.Dir = workingDir
	fmt.Println("🏗️  Running Terragrunt Apply...")

	output, err := apply.CombinedOutput()
	if err != nil {
		return fmt.Errorf("apply failed: %w\n%s", err, string(output))
	}

	fmt.Println("✅ Terragrunt Apply completed successfully.")
	return nil
}
