<template>
  <div id="app">
    <b-navbar toggleable="lg" type="dark" variant="primary">
      <b-navbar-brand href="#">BrowserPhone</b-navbar-brand>

      <b-navbar-toggle target="nav-collapse"></b-navbar-toggle>

      <b-collapse id="nav-collapse" is-nav>
        <b-navbar-nav class="ml-auto">
          <b-nav-text v-if="identity">Signed in as <strong>{{ identity }}</strong></b-nav-text>
        </b-navbar-nav>
      </b-collapse>
    </b-navbar>

    <b-container>
      <b-row class="justify-content-center mt-5">
        <b-col cols="12" md="6">

          <b-card>
            <b-form-input size="lg" slot="header" type="tel" class="my-2 number border-info" autofocus v-model="number"></b-form-input>

            <b-row>
              <b-col v-for="key in keys" cols="4" class="text-center mb-3" :key="key">
                <b-btn size="lg" @click="keyDown(key)">{{ key }}</b-btn>
              </b-col>

              <b-col cols="4" class="text-center mb-2">
                <b-btn size="lg" :variant="ongoingCall ? 'danger' : 'success'" @click="toggleCall">
                  <i :class="{ 'fas': true, 'fa-phone': !ongoingCall, 'fa-phone-slash': ongoingCall }"></i>
                </b-btn>
              </b-col>
            </b-row>

            <div slot="footer" v-if="state">
              {{ state }}
            </div>
          </b-card>

        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import axios from 'axios'
import Twilio from 'twilio-client'

import config from './config.js'

export default {
  name: 'app',

  computed: {
    keys() {
      return [1, 2, 3, 4, 5, 6, 7, 8, 9, '+', 0]
    },
  },

  data() {
    return {
      identity: null,
      number: '',
      ongoingCall: false,
      phone: {
        conn: null,
        device: null,
      },
      state: '',
    }
  },

  methods: {
    announceStatus(state) {
      this.state = state
      window.setTimeout(() => {
        this.state = ''
      }, 2000)
    },

    keyDown(key) {
      this.number = `${this.number}${key}`
    },

    setupPhone() {
      if (!this.phone.device) {
        this.phone.device = new Twilio.Device()
        this.phone.device.on('ready', () => this.announceStatus('Phone ready...'))
        this.phone.device.on('error', err => console.error(err))
        this.phone.device.on('connect', conn => {
          this.phone.conn = conn
          this.ongoingCall = true
          this.announeState('Call connected')
        })
        this.phone.device.on('disconnect', () => {
          this.phone.conn = null
          this.ongoingCall = false
          this.announeState('Call disconnected')
        })
        this.phone.device.on('offline', () => {
          this.announceStatus('Phone disconnected, reconnecting...')
          this.setupPhone()
        })
      }

      const opts = { codecPreferences: ['opus', 'pcmu'], fakeLocalDTMF: true }

      axios.get(config.capabilityTokenURL)
        .then(resp => {
          this.identity = resp.data.identity
          this.phone.device.setup(resp.data.token, opts)
        })
        .catch(err => console.error(err))
    },

    toggleCall() {
      if (this.ongoingCall) {
        this.phone.device.disconnectAll()
        return
      }

      // handle incoming

      if (this.number) {
        this.announceStatus(`Dialing ${this.number}...`)
        this.phone.device.connect({
          To: this.number,
        })
      }
    },
  },

  mounted() {
    this.announceStatus('Phone loaded...')
    this.setupPhone()
  },

}
</script>

<style scoped>
.btn-lg {
  font-size: 2rem;
  height: 2em;
  width: 2em;
}
input.form-control-lg {
  font-size: 2rem;
}
.number {
  background-color: transparent;
  color: #fff;
}
</style>
