# syntax=docker/dockerfile:1

ARG NODE_VERSION=20.15.0

################################################################################
# Use node image for base image for all stages.
FROM node:${NODE_VERSION}-alpine as base

# Set working directory for all build stages.
WORKDIR /usr/src/app

################################################################################
# Create a stage for installing production dependencies.
FROM base as deps

# Install production dependencies
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

################################################################################
# Create a stage for building the application.
FROM deps as build

# Install all dependencies (including devDependencies)
RUN npm ci

# Copy the rest of the source files into the image.
COPY . .

# Run the build script.
RUN npm run build

################################################################################
# Create a new stage to run the application with minimal runtime dependencies
FROM base as final

# Use production node environment by default.
ENV NODE_ENV=production

# Copy package.json so that package manager commands can be used.
COPY package.json ./

# Copy the production dependencies from the deps stage and also
# the built application from the build stage into the image.
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/. ./

# Change ownership of the application directory to the node user
RUN chown -R node:node /usr/src/app

# Switch to non-root user
USER node

# Expose the port that the application listens on.
EXPOSE 5173

# Run the application.
CMD ["npm", "run", "dev"]
