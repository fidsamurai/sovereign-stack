package prereqs

import (
	"fmt"
	"os"
	"os/exec"
	"reflect"
	"strings"

	"gopkg.in/yaml.v3"
)

type Config struct {
	REGION                    string `yaml:"aws_region" module:"root"`
	CIDR                      string `yaml:"cidr_block" module:"network"`
	AZ1                       string `yaml:"availability_zone_pri1" module:"network"`
	AZ2                       string `yaml:"availability_zone_pri2" module:"network"`
	AZ3                       string `yaml:"availability_zone_pub1" module:"network"`
	AZ4                       string `yaml:"availability_zone_pub2" module:"network"`
	Private1_CIDR             string `yaml:"private1_cidr_block" module:"network"`
	Private2_CIDR             string `yaml:"private2_cidr_block" module:"network"`
	Public1_CIDR              string `yaml:"public1_cidr_block" module:"network"`
	Public2_CIDR              string `yaml:"public2_cidr_block" module:"network"`
	ASG_Cplane_Key_Name       string `yaml:"asg_cplane_key_name" module:"lt-asg"`
	ASG_Cplane_Max_VCpu_Count string `yaml:"asg_cplane_max_vcpu_count" module:"lt-asg"`
	ASG_Cplane_Min_Memory_MiB string `yaml:"asg_cplane_min_memory_mib" module:"lt-asg"`
	ASG_Cplane_Max_Memory_MiB string `yaml:"asg_cplane_max_memory_mib" module:"lt-asg"`
}

func CheckCommands() error {
	//List of prerequisites to check
	prereqs := []string{"terragrunt", "aws"}

	for _, command := range prereqs {
		path, err := exec.LookPath(command)
		if err != nil {
			return fmt.Errorf("%v is not installed. Please install it and try again.\n", command)
		}
		fmt.Printf("%v is installed at %v\n", command, path)
	}
	return nil
}

func CheckConfigs() error {
	configs := []string{
		"../config-dev-primary.yaml",
		"../config-dev-dr.yaml",
		"../config-prod-primary.yaml",
		"../config-prod-dr.yaml",
	}

	target := &Config{}

	for _, path := range configs {
		data, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("failed to read file %s: %w", path, err)
		}

		splitPath := strings.Split(path, "-")
		env := splitPath[1]
		zone := splitPath[2]

		// Reset target for each file to ensure we don't carry over values
		target = &Config{}
		if err := yaml.Unmarshal(data, target); err != nil {
			return fmt.Errorf("failed to parse yaml %s: %w", path, err)
		}

		// 1. Validate via Reflection
		v := reflect.Indirect(reflect.ValueOf(target))
		t := v.Type()

		for i := 0; i < v.NumField(); i++ {
			//fieldValue := v.Field(i).String()
			yamlTag := t.Field(i).Tag.Get("yaml")

			if v.Field(i).IsZero() {
				return fmt.Errorf("file %s is missing required field: %s", path, yamlTag)
			}
		}
		if err := WriteModuleVars(target, env, zone); err != nil {
			return err
		}
	}
	return nil
}

func WriteModuleVars(target any, env string, zone string) error {
	v := reflect.Indirect(reflect.ValueOf(target))
	t := v.Type()

	// 1. Create a map to hold data for each module
	// Key: module name, Value: content for that module's env_vars.yaml
	moduleData := make(map[string]string)

	for i := 0; i < v.NumField(); i++ {
		fieldValue := v.Field(i).String()
		yamlKey := t.Field(i).Tag.Get("yaml")
		moduleName := t.Field(i).Tag.Get("module")

		if moduleName == "" {
			continue // Skip fields without a module tag
		}

		// Append this variable to the specific module's string
		if moduleName == "root" {
			key := yamlKey
			if key == "aws_region" {
				key = "region"
			}
			moduleData[moduleName] += fmt.Sprintf("  %s = \"%s\"\n", key, fieldValue)

		} else {
			moduleData[moduleName] += fmt.Sprintf("%s: \"%s\"\n", yamlKey, fieldValue)
		}
	}

	// 2. Write the files to the specific region/env path
	for module, content := range moduleData {
		cleanZone := strings.TrimSuffix(zone, ".yaml")

		// Example Path: ../terraform/env/dev/network/env_vars.yaml
		if module == "root" {
			dirPath := fmt.Sprintf("../terraform/env/%s/%s/region.hcl", env, cleanZone)

			// Check if file needs a newline prepended
			needsNewline := false
			if info, err := os.Stat(dirPath); err == nil && info.Size() > 0 {
				f, err := os.Open(dirPath)
				if err == nil {
					buf := make([]byte, 1)
					if _, err := f.ReadAt(buf, info.Size()-1); err == nil {
						if buf[0] != '\n' {
							needsNewline = true
						}
					}
					f.Close()
				}
			}

			file, err := os.OpenFile(dirPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
			if err != nil {
				return fmt.Errorf("failed to write %s: %w", dirPath, err)
			}
			defer file.Close()

			if needsNewline {
				file.WriteString("\n")
			}

			// Wrap in locals block
			finalContent := fmt.Sprintf("locals {\n%s}\n", content)

			if _, err := file.WriteString(finalContent); err != nil {
				return fmt.Errorf("failed to write %s: %w", dirPath, err)
			}
			fmt.Printf("📂 Written vars for module [%s] to %s\n", module, dirPath)
			continue
		}

		dirPath := fmt.Sprintf("../terraform/env/%s/%s/%s", env, cleanZone, module)

		// Create the directory if it doesn't exist
		if err := os.MkdirAll(dirPath, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dirPath, err)
		}

		filePath := dirPath + "/env_vars.yaml"
		err := os.WriteFile(filePath, []byte(content), 0644)
		if err != nil {
			return fmt.Errorf("failed to write %s: %w", filePath, err)
		}
		fmt.Printf("📂 Written vars for module [%s] to %s\n", module, filePath)
	}

	return nil
}
