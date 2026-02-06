package prereqs

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"

	"gopkg.in/yaml.v3"
)

type Config struct {
	EnvProd                    bool     `yaml:"env_prod" module:"root"`
	Profile                    string   `yaml:"profile" module:"root"`
	REGION                     string   `yaml:"aws_region" module:"root"`
	CIDR                       string   `yaml:"cidr_block" module:"network"`
	Private_AVAILABILITY_ZONES []string `yaml:"private_availability_zones,flow" module:"network"`
	Public_AVAILABILITY_ZONES  []string `yaml:"public_availability_zones,flow" module:"network"`
	Private_CIDR_BLOCKS        []string `yaml:"private_cidr_blocks,flow" module:"network"`
	Public_CIDR_BLOCKS         []string `yaml:"public_cidr_blocks,flow" module:"network"`
	NAT_AMI                    string   `yaml:"nat_ami" module:"network"`
	NAT_INSTANCE_TYPE          string   `yaml:"nat_instance_type" module:"network"`
	ASG_Cplane_Key_Name        string   `yaml:"asg_cplane_key_name" module:"lt-asg"`
	ASG_Cplane_Max_VCpu_Count  string   `yaml:"asg_cplane_max_vcpu_count" module:"lt-asg"`
	ASG_Cplane_Min_Memory_MiB  string   `yaml:"asg_cplane_min_memory_mib" module:"lt-asg"`
	ASG_Cplane_Max_Memory_MiB  string   `yaml:"asg_cplane_max_memory_mib" module:"lt-asg"`
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
	var requiredProfiles []string

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

		requiredProfiles = append(requiredProfiles, target.Profile)

		if err := WriteModuleVars(target, env, zone); err != nil {
			return err
		}
	}

	// Validate profiles
	if err := CheckProfiles(requiredProfiles); err != nil {
		return err
	}

	return nil
}

func CheckProfiles(required []string) error {
	// Get available profiles
	cmd := exec.Command("aws", "configure", "list-profiles")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to list aws profiles: %w", err)
	}

	available := make(map[string]bool)
	for _, p := range strings.Split(string(output), "\n") {
		if strings.TrimSpace(p) != "" {
			available[strings.TrimSpace(p)] = true
		}
	}

	// Check if required profiles exist
	var missing []string
	for _, req := range required {
		if !available[req] {
			missing = append(missing, req)
			fmt.Printf("❌ AWS Profile '%s' MISSING\n", req)
		} else {
			fmt.Printf("✅ AWS Profile '%s' found\n", req)
		}
	}

	if len(missing) > 0 {
		return fmt.Errorf("missing profiles: %v. Please configure them using 'aws configure --profile <name>'", strings.Join(missing, ", "))
	}

	return nil
}

func WriteModuleVars(target any, env string, zone string) error {
	v := reflect.Indirect(reflect.ValueOf(target))
	t := v.Type()

	// Key: module name, Value: map of keys to interfaces (values)
	moduleData := make(map[string]map[string]any)

	for i := 0; i < v.NumField(); i++ {
		field := v.Field(i)
		structField := t.Field(i)
		yamlTag := structField.Tag.Get("yaml")
		yamlKey := strings.Split(yamlTag, ",")[0]
		moduleName := structField.Tag.Get("module")

		if moduleName == "" {
			continue
		}

		if moduleData[moduleName] == nil {
			moduleData[moduleName] = make(map[string]any)
		}

		key := yamlKey
		if moduleName == "root" && key == "aws_region" {
			key = "region"
		}
		moduleData[moduleName][key] = field.Interface()
	}

	cleanZone := strings.TrimSuffix(zone, ".yaml")

	for module, data := range moduleData {
		if module == "root" {
			dirPath := fmt.Sprintf("../terraform/env/%s/%s/region.hcl", env, cleanZone)
			if err := os.MkdirAll(filepath.Dir(dirPath), 0755); err != nil {
				return fmt.Errorf("failed to create directory %s: %w", filepath.Dir(dirPath), err)
			}

			var hclContent strings.Builder
			hclContent.WriteString("locals {\n")
			for k, val := range data {
				hclContent.WriteString(fmt.Sprintf("  %s = %s\n", k, formatHCL(val)))
			}
			hclContent.WriteString("}\n")

			if err := os.WriteFile(dirPath, []byte(hclContent.String()), 0644); err != nil {
				return fmt.Errorf("failed to write %s: %w", dirPath, err)
			}
			fmt.Printf("📂 Written vars for module [%s] to %s\n", module, dirPath)
			continue
		}

		dirPath := fmt.Sprintf("../terraform/env/%s/%s/%s", env, cleanZone, module)
		if err := os.MkdirAll(dirPath, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dirPath, err)
		}

		yamlData, err := yaml.Marshal(data)
		if err != nil {
			return fmt.Errorf("failed to marshal yaml for module %s: %w", module, err)
		}

		filePath := filepath.Join(dirPath, "env_vars.yaml")
		if err := os.WriteFile(filePath, yamlData, 0644); err != nil {
			return fmt.Errorf("failed to write %s: %w", filePath, err)
		}
		fmt.Printf("📂 Written vars for module [%s] to %s\n", module, filePath)
	}

	return nil
}

// formatHCL helper to convert Go values to HCL-compatible strings
func formatHCL(val any) string {
	switch v := val.(type) {
	case string:
		return fmt.Sprintf("\"%s\"", v)
	case bool:
		return fmt.Sprintf("%v", v)
	case []string:
		var items []string
		for _, s := range v {
			items = append(items, fmt.Sprintf("\"%s\"", s))
		}
		return fmt.Sprintf("[%s]", strings.Join(items, ", "))
	default:
		// Fallback for other types using JSON-like representation which HCL often accepts
		return fmt.Sprintf("%v", v)
	}
}
