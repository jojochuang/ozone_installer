# Ozone Installer

Apache Ozone installer project - currently in early development stage with minimal implementation.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Current Repository State

This repository is in the initial development phase and contains only basic project structure:
- `README.md` - Minimal project description
- `LICENSE` - Apache License 2.0
- No build system, dependencies, or implementation code yet

## Working Effectively

### Repository Setup
- Clone the repository: Repository is available at `https://github.com/jojochuang/ozone_installer`
- Navigate to repository root: `cd /home/runner/work/ozone_installer/ozone_installer`
- Check current status: `git --no-pager status`
- View repository contents: `ls -la`

### Available Development Environment
The development environment includes:
- Python 3.12.3 (`python3 --version`)
- Java OpenJDK 17.0.16 (`java -version`)
- Node.js v20.19.5 and npm 10.8.2 (`node --version && npm --version`)
- Apache Maven 3.9.11 (`mvn --version`)
- Gradle 9.0.0 (`gradle --version`)

### Current Limitations
- **NO BUILD PROCESS**: Repository currently has no build system configured
- **NO TESTS**: No test framework or tests exist yet
- **NO DEPENDENCIES**: No package.json, pom.xml, requirements.txt, or similar dependency files
- **NO IMPLEMENTATION**: Only placeholder README and license file exist

## Development Guidelines

### For New Development
When adding initial implementation to this repository:

1. **Determine Technology Stack**: Based on Apache Ozone being a Java-based project, consider:
   - Java with Maven: `mvn archetype:generate` for new Java project
   - Python installer: `python3 -m venv venv && source venv/bin/activate`
   - Shell script installer: Create executable `.sh` files

2. **Create Project Structure**: 
   - Add appropriate project files (pom.xml for Java, package.json for Node, requirements.txt for Python)
   - Create src/main directory structure for implementation
   - Add test directories and initial test files

3. **Add Build Configuration**:
   - Configure build timeouts appropriately (Java builds can take 5-15 minutes)
   - Add GitHub Actions workflow in `.github/workflows/` for CI/CD
   - NEVER CANCEL long-running builds - set timeouts to 60+ minutes

### Validation Requirements
Once implementation is added:

- **Build Validation**: Always test complete build process before documenting
- **Test Execution**: Run full test suite and document expected runtime
- **Installation Testing**: Test actual installation scenarios end-to-end
- **Documentation**: Update this file with specific build commands and timing

## Future Instructions Template

When implementation is added, update this section with:

```
### Building the Project
- Install dependencies: [specific command]
- Build: [specific command] -- takes X minutes. NEVER CANCEL. Set timeout to Y+ minutes.
- Test: [specific command] -- takes X minutes. NEVER CANCEL. Set timeout to Y+ minutes.

### Running the Installer
- [Specific commands to run the installer]
- [Expected outputs and validation steps]

### Development Workflow
- [Steps to modify installer]
- [How to test changes]
- [Validation requirements]
```

## Current Git Operations

### Working with Git
- Check status: `git --no-pager status`
- View log: `git --no-pager log --oneline -10`
- View changes: `git --no-pager diff`
- Current branch: `copilot/fix-3`

### File Operations Validated
- Repository root: `/home/runner/work/ozone_installer/ozone_installer`
- Create directories: `mkdir -p .github` (validated)
- File listing: `ls -la` (validated)
- Python available: `python3 --version` (validated: 3.12.3)
- Java available: `java -version` (validated: OpenJDK 17.0.16)

## Critical Notes

- **REPOSITORY IS MINIMAL**: Do not expect existing build processes, tests, or implementation
- **PLAN FOR FUTURE**: Instructions should be updated as implementation develops
- **APACHE OZONE CONTEXT**: This installer is intended for Apache Ozone distributed storage system
- **NO NETWORK ACCESS**: External API calls and downloads may be blocked in development environment

## Action Items for Implementation

When starting development:
1. Research Apache Ozone installation requirements
2. Decide on implementation approach (Java, Python, shell script, or combination)
3. Create initial project structure
4. Add build system configuration
5. Implement basic installer functionality
6. Add comprehensive tests
7. Update these instructions with validated commands and processes

## Common Commands (Currently Available)

### Directory Navigation
```bash
cd /home/runner/work/ozone_installer/ozone_installer  # Repository root
pwd                                                   # Current directory
ls -la                                               # List files
```

### Git Operations
```bash
git --no-pager status                                # Check status
git --no-pager log --oneline -5                     # Recent commits
git --no-pager diff                                  # View changes
```

### System Information
```bash
python3 --version                                    # Python version
java -version                                        # Java version
mvn --version                                        # Maven version
node --version && npm --version                      # Node/npm versions
```

**Remember**: Always validate commands in the actual repository environment before adding them to documentation or implementation plans.