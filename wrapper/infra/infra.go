package infra

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// SSHKeys generates required keys. Note: Changed firstTime to bool.
func SSHKeys(firstTime bool) error {
	if !firstTime {
		return nil
	}

	keys := []string{"dev_cplane_pri", "dev_cplane_dr", "dev_worker_pri", "dev_worker_dr", "dev_jump_server",
		"prod_cplane_pri", "prod_cplane_dr", "prod_worker_pri", "prod_worker_dr", "prod_jump_server",
		"dev_jump_dr", "dev_jump_pri", "prod_jump_dr", "prod_jump_pri"}

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

func Apply(firstTime bool, modulesList []string) error {
	if firstTime {
		fmt.Println("🏗️  Running Initial Full Deployment (terragrunt apply -a)...")
		apply := exec.Command("terragrunt", "apply", "-a", "-auto-approve")
		apply.Dir = "../terraform/"
		if out, err := apply.CombinedOutput(); err != nil {
			return fmt.Errorf("initial apply failed: %w\n%s", err, string(out))
		}
		fmt.Println("✅ Initial Deployment completed successfully.")
		return nil
	}

	// Modular Updates (firstTime == false)
	for _, module := range modulesList {
		if module == "" {
			continue
		}
		var workingDir string
		var isAll bool

		if module == "all" {
			workingDir = "../terraform/"
			isAll = true
		} else {
			moduleSplit := strings.Split(module, "-")
			if len(moduleSplit) != 3 {
				return fmt.Errorf("invalid module format: '%s'. Expected env-region-component (e.g., dev-dr-network)", module)
			}
			workingDir = fmt.Sprintf("../terraform/env/%s/%s/%s", moduleSplit[0], moduleSplit[1], moduleSplit[2])
			isAll = false
		}

		// Plan step
		var plan *exec.Cmd
		planArgs := []string{"plan"}
		if isAll {
			planArgs = append(planArgs, "-a")
		}
		plan = exec.Command("terragrunt", planArgs...)
		plan.Dir = workingDir
		fmt.Printf("🔍 Running Plan for: %s...\n", module)

		if out, err := plan.CombinedOutput(); err != nil {
			return fmt.Errorf("plan failed for %s: %w\n%s", module, err, string(out))
		} else {
			fmt.Printf("%s\n", out)
		}

		// User Approval
		fmt.Printf("❓ Plan successful for %s. Type 'true' to apply: ", module)
		var approval bool
		_, err := fmt.Scanf("%t", &approval)
		if err != nil || !approval {
			fmt.Printf("⏭️  Skipping apply for %s (received: %v)\n", module, approval)
			continue
		}

		// Apply step
		var apply *exec.Cmd
		applyArgs := []string{"apply", "-auto-approve"}
		if isAll {
			applyArgs = append(applyArgs, "-a")
		}
		apply = exec.Command("terragrunt", applyArgs...)
		apply.Dir = workingDir
		fmt.Printf("🏗️  Running Apply for %s...\n", module)

		if out, err := apply.CombinedOutput(); err != nil {
			return fmt.Errorf("apply failed for %s: %w\n%s", module, err, string(out))
		}
		fmt.Printf("✅ %s deployed successfully.\n", module)
	}

	return nil
}
