# Contributing to Docker Setup Tool

Thank you for considering contributing to the Docker Setup Tool! Your help makes this project better for everyone. This document provides guidelines and instructions for contributing.

## Getting Started

Our project aims to simplify Docker infrastructure setup. Before you begin contributing, please ensure you have:

1. A good understanding of Docker and container orchestration
2. Familiarity with shell scripting
3. Basic knowledge of Git and GitHub workflows

## Development Environment Setup

First, clone the repository and set up your development environment:

```bash
# Clone the repository
git clone https://github.com/jackkweyunga/docker-setup.git

# Enter the project directory
cd docker-setup

# Make the build script executable
chmod +x build.sh

# Build the project
make
```

## Making Changes

We use a standard Git workflow for contributions:

1. Create a new branch for your feature or fix:
```bash
git checkout -b feature-name
```

2. Make your changes, following our coding standards:
   - Use clear, descriptive variable names
   - Add comments for complex logic
   - Follow the Google Shell Style Guide for bash scripts
   - Keep functions focused and single-purpose

3. Test your changes thoroughly:
   - Ensure the build process works
   - Test on a fresh Docker installation
   - Verify all features still work as expected

4. Commit your changes with clear messages:
```bash
git commit -m "Add feature: description of what you added"
```

## Pull Request Process

1. Update the README.md with details of changes if needed
2. Update the version numbers following Semantic Versioning
3. Push your changes and create a Pull Request
4. Respond to any feedback from maintainers

## Testing Guidelines

Before submitting your PR, please ensure:

1. The build process completes successfully
2. Installation works on a fresh system
3. All features are documented

## Documentation

If you're adding new features, please include:

1. Clear documentation in the code
2. Updates to the README if needed
3. Examples of how to use new features
4. Any necessary troubleshooting guidance

## Code Review Process

1. Maintainers will review your PR
2. Address any requested changes
3. Once approved, your code will be merged
4. Your contribution will be added to the changelog

## Questions or Problems?

If you have questions or run into issues:

1. Check existing issues for similar problems
2. Create a new issue with clear details if needed
3. Tag it appropriately (bug, enhancement, question)

Thank you for contributing to make Docker Setup Tool better for everyone!