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
            <b-form-input
              autofocus
              class="my-2 number border-info"
              @keypress="evt => keypress(evt)"
              size="lg"
              slot="header"
              type="tel"
              v-model="number"
              ></b-form-input>

            <b-row class="justify-content-center">
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
      return [1, 2, 3, 4, 5, 6, 7, 8, 9, '*', 0, '#']
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
      ringing: false,
      state: '',
      wakeLock: {
        obj: null,
        request: null,
      },
    }
  },

  methods: {
    announceStatus(state, autoClear = true) {
      this.state = state

      if (autoClear) {
        window.setTimeout(() => {
          this.state = ''
        }, 2000)
      }
    },

    keyDown(key) {
      if (this.ongoingCall) {
        this.phone.conn.sendDigits(key)
        return
      }

      this.number = `${this.number}${key}`
    },

    keypress(evt) {
      if (evt.keyCode === 13) {
        this.toggleCall()
      }
    },

    setupPhone() {
      if (!this.phone.device) {
        this.phone.device = new Twilio.Device()
        this.phone.device.on('ready', () => this.announceStatus('Phone ready...'))
        this.phone.device.on('error', err => console.error(err))
        this.phone.device.on('connect', conn => {
          this.phone.conn = conn
          this.ongoingCall = true
          this.ringing = false
          this.announceStatus('Call connected')
          this.setWakeLock(true)
        })
        this.phone.device.on('disconnect', () => {
          this.phone.conn = null
          this.ongoingCall = false
          this.announceStatus('Call disconnected')
          this.setWakeLock(false)
        })
        this.phone.device.on('incoming', conn => {
          this.announceStatus(`Incoming call from ${conn.parameters.From}...`, false)
          this.phone.conn = conn
          this.ringing = true
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
          this.ringing = false
        })
        .catch(err => console.error(err))
    },

    async setWakeLock(lock) {
      if (!navigator || !navigator.getWakeLock) {
        // No wake-lock functionality present in this browser
        console.debug('Browser has no wake-lock support')
        return
      }

      if (!this.wakeLock.obj) {
        this.wakeLock.obj = await navigator.getWakeLock('screen')
      }

      if (lock && !this.wakeLock.request) {
        this.wakeLock.request = this.wakeLock.obj.createRequest()
        this.announceStatus('Wake-lock aquired: Keeping display active...')
        return
      }

      if (!lock && this.wakeLock.request) {
        this.wakeLock.request.cancel()
        this.wakeLock.request = null
        this.announceStatus('Wake-lock disabled: Screen may sleep...')
      }
    },

    toggleCall() {
      if (this.ringing && this.phone.conn) {
        this.phone.conn.accept()
        return
      }

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
