import Vue from 'vue'

import BootstrapVue from 'bootstrap-vue'

import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue/dist/bootstrap-vue.css'
import 'bootswatch/dist/darkly/bootstrap.css'

import app from './app.vue'

Vue.use(BootstrapVue)

new Vue({
  components: { app },
  el: '#app',
  render: c => c('app'),
})
