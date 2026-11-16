<script setup lang="ts">
// The card the signed-out pages (sign in, forgot password) sit in: centred on the
// page, with Pin's logo. Their forms use the .auth-form styles in styles.css.
</script>

<template>
  <div class="page">
    <div class="card panel">
      <div class="brand">
        <img src="/pin-logo.png" alt="" />
        <div>
          <div class="brand-name">Pin Admin</div>
          <div class="brand-sub">Back office</div>
        </div>
      </div>
      <slot />
    </div>
  </div>
</template>

<style scoped>
.page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.panel {
  width: min(400px, 100%);
  padding: 28px 28px 24px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
}

.brand img {
  height: 40px;
  width: auto;
}

.brand-name {
  font-size: 17px;
  font-weight: 800;
  line-height: 1.1;
}

.brand-sub {
  font-size: 12px;
  color: var(--muted);
}
</style>
